java_import java.nio.channels.ServerSocketChannel

require 'zmachine/channel'

module ZMachine
  class TCPChannel < Channel

    attr_reader :selectable_channel
    attr_reader :connect_pending

    def initialize(socket, signature, selector)
      super
      @selectable_channel = socket
      @close_scheduled = false
      @connect_pending = false
      @outbound_queue = []
    end

    def accept(client_signature)
      client_socket = socket.accept
      return unless client_socket
      client_socket.configure_blocking(false)
      TCPChannel.new(client_socket, client_signature, @selector)
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
      puts "update_events(): #{events.inspect}, #{current_events.inspect}"
    end

    def has_more?
      false
    end

    def current_events
      if @socket.respond_to?(:accept)
        return SelectionKey::OP_ACCEPT
      end

      events = 0

      if @connect_pending
        events |= SelectionKey::OP_CONNECT
      else
        events |= SelectionKey::OP_READ
        events |= SelectionKey::OP_WRITE unless @outbound_queue.empty?
      end

      puts "current_events(): #{events.inspect}"

      return events
    end
  end
end
