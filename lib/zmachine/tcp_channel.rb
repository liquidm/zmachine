module ZMachine
  class TCPChannel

    attr_reader :selectable_channel
    attr_reader :signature
    attr_reader :connect_pending

    def initialize(selectable_channel, signature, selector)
      @selectable_channel = selectable_channel
      @signature = signature
      @selector = selector
      @close_scheduled = false
      @connect_pending = false
      @outbound_queue = []
    end

    def register
      @channel_key ||= @selectable_channel.register(@selector, current_events, self)
    end

    def close
      if @channel_key
        @channel_key.cancel
        @channel_key = nil
      end

      @selectable_channel.close rescue nil
    end

    def cleanup
      @selectable_channel = nil
    end

    def send_data(data)
      return if @close_scheduled
      buffer = ByteBuffer.wrap(data.to_java_bytes)
      if buffer.remaining() > 0
        @outbound_queue << buffer
        update_events
      end
    end

    def read_inbound_data(buffer)
      buffer.clear
      raise IOException.new("eof") if @selectable_channel.read(buffer) == -1
      buffer.flip
      return if buffer.limit == 0
      String.from_java_bytes(buffer.array[buffer.position...buffer.limit])
    end

    def write_outbound_data
      until @outbound_queue.empty?
        buffer = @outbound_queue.first
        selectable_channel.write(buffer) if buffer.remaining > 0

        # Did we consume the whole outbound buffer? If yes,
        # pop it off and keep looping. If no, the outbound network
        # buffers are full, so break out of here.
        if buffer.remaining == 0
          @outbound_queue.shift
        else
          break
        end
      end

      if @outbound_queue.empty? && !@close_scheduled
        update_events
      end

      return (@close_scheduled && @outbound_queue.empty?) ? false : true
    end

    def finish_connecting
      @selectable_channel.finish_connect
      @connect_pending = false
      update_events
      return true
    end

    def schedule_close(after_writing)
      @outbound_queue.clear unless after_writing

      if @outbound_queue.empty?
        return true
      else
        update_events
        @close_scheduled = true
        return false
      end
    end

    def peer_name
      sock = @selectable_channel.socket
      [sock.port, sock.inet_address.host_address]
    end

    def sock_name
      sock = selectable_channel.socket
      [sock.local_port, sock.local_address.host_address]
    end

    def connect_pending=(value)
      @connect_pending = value
      update_events
    end

    def update_events
      return unless @channel_key
      events = current_events
      if @channel_key.interest_ops != events
        @channel_key.interest_ops(events)
      end
    end

    def current_events
      events = 0

      if @connect_pending
        events |= SelectionKey::OP_CONNECT
      else
        events |= SelectionKey::OP_READ
        events |= SelectionKey::OP_WRITE unless @outbound_queue.empty?
      end

      return events
    end
  end
end
