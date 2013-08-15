module ZMachine
  class Channel

    attr_reader :channel
    attr_reader :signature
    attr_reader :watch_only
    attr_accessor :notify_readable
    attr_accessor :notify_writable
    attr_reader :connect_pending
    attr_accessor :attached

    def initialize(channel, signature, sel)
      @channel = channel
      @signature = signature
      @selector = sel
      @close_scheduled = false
      @connect_pending = false
      @watch_only = false
      @attached = false
      @notify_readable = false
      @notify_writable = false
      @outbound_queue = []
    end

    def register
      @channel_key ||= @channel.register(@selector, current_events, self)
    end

    def close
      if @channel_key
        @channel_key.cancel
        @channel_key = nil
      end

      @channel.close rescue nil
    end

    def cleanup
      @channel = nil
    end

    def schedule_outbound_data(buffer)
      return if @close_scheduled
      if buffer.remaining() > 0
        @outbound_queue << buffer
        update_events
      end
    end

    def read_inbound_data(buffer)
      raise IOException.new("eof") if @channel.read(buffer) == -1
    end

    def write_outbound_data
      until @outbound_queue.empty?
        buffer = @outbound_queue.first
        channel.write(buffer) if buffer.remaining > 0

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
      @channel.finish_connect
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
      sock = @channel.socket
      [sock.port, sock.inet_address.host_address]
    end

    def sock_name
      sock = channel.socket
      [sock.local_port, sock.local_address.host_address]
    end

    def connect_pending=(value)
      @connect_pending = value
      update_events
    end

    def watch_only=(value)
      @watch_only = value
      update_events
    end

    def notify_readable=(mode)
      @notify_readable = mode
      update_events
    end

    def notify_writable=(mode)
      @notify_writable = mode
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

      if @watch_only
        events |= SelectionKey::OP_READ if @notify_readable
        events |= SelectionKey::OP_WRITE if @notify_writable
      else
        if @connect_pending
          events |= SelectionKey::OP_CONNECT
        else
          events |= SelectionKey::OP_READ
          events |= SelectionKey::OP_WRITE unless @outbound_queue.empty?
        end
      end

      return events
    end
  end
end
