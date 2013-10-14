java_import java.nio.channels.ServerSocketChannel

require 'zmachine/channel'

module ZMachine
  class TCPChannel < Channel

    attr_reader :connect_pending

    def initialize(selector)
      super(selector)
      @close_scheduled = false
      @connect_pending = false
      @server_socket   = false
    end

    def register
      @channel_key ||= @socket.register(@selector, current_events, self)
    end

    def bind(address, port)
      @server_socket = true
      address = InetSocketAddress.new(address, port)
      @socket = ServerSocketChannel.open
      @socket.configure_blocking(false)
      @socket.bind(address)
    end

    def accept
      client_socket = socket.accept
      return unless client_socket
      client_socket.configure_blocking(false)
      channel = TCPChannel.new(@selector)
      channel.socket = client_socket
      channel
    end

    def connect(address, port)
      address = InetSocketAddress.new(address, port)
      @socket = SocketChannel.open
      @socket.configure_blocking(false)

      if socket.connect(address)
        # Connection returned immediately. Can happen with localhost
        # connections.
        # WARNING, this code is untested due to lack of available test
        # conditions.  Ought to be be able to come here from a localhost
        # connection, but that doesn't happen on Linux. (Maybe on FreeBSD?)
        # The reason for not handling this until we can test it is that we
        # really need to return from this function WITHOUT triggering any EM
        # events.  That's because until the user code has seen the signature
        # we generated here, it won't be able to properly dispatch them. The
        # C++ EM deals with this by setting pending mode as a flag in ALL
        # eventable descriptors and making the descriptor select for
        # writable. Then, it can send UNBOUND and CONNECTION_COMPLETED on the
        # next pass through the loop, because writable will fire.
        raise RuntimeError.new("immediate-connect unimplemented")
      end
    end

    def close_connection(flush = true)
      @reactor.unbind_channel(self) if schedule_close(flush)
    end

    def close
      if @channel_key
        @channel_key.cancel
        @channel_key = nil
      end

      @socket.close rescue nil
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
      raise IOException.new("eof") if @socket.read(buffer) == -1
      buffer.flip
      return if buffer.limit == 0
      String.from_java_bytes(buffer.array[buffer.position...buffer.limit])
    end

    def write_outbound_data
      until @outbound_queue.empty?
        buffer = @outbound_queue.first
        @socket.write(buffer) if buffer.remaining > 0
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
      @socket.finish_connect
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

    # TODO: fix these
    def peer_name
      sock = @socket.socket
      [sock.port, sock.inet_address.host_address]
    end

    def sock_name
      sock = @socket.socket
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

    # these two are a bit misleading .. only used for the zmq channel
    def has_more?
      false
    end

    def can_send?
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

      return events
    end
  end
end
