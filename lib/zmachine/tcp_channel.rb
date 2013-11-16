java_import java.io.IOException
java_import java.net.InetSocketAddress
java_import java.nio.channels.SocketChannel
java_import java.nio.channels.ServerSocketChannel

require 'zmachine/channel'

module ZMachine
  class TCPChannel < Channel

    def selectable_fd
      @socket
    end

    def bind(address, port)
      address = InetSocketAddress.new(address, port)
      @socket = ServerSocketChannel.open
      @socket.configure_blocking(false)
      @socket.bind(address)
    end

    def bound?
      @socket.is_a?(ServerSocketChannel) and @socket.bound?
    end

    def accept
      client_socket = @socket.accept
      return unless client_socket
      client_socket.configure_blocking(false)
      TCPChannel.new.tap do |channel|
        channel.socket = client_socket
      end
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
        raise RuntimeError.new("immediate-connect unimplemented")
      end
    end

    def connection_pending?
      @socket.connection_pending?
    end

    def finish_connecting
      return unless connection_pending?
      @socket.finish_connect # XXX: finish_connect might return false
      return true
    end

    def connected?
      @socket.connected?
    end

    def read_inbound_data
      buffer = @inbound_buffer
      buffer.clear
      raise IOException.new("EOF") if @socket.read(buffer) == -1
      buffer.flip
      return if buffer.limit == 0
      String.from_java_bytes(buffer.array[buffer.position...buffer.limit])
    end

    def send_data(data)
      raise RuntimeError.new("send_data called after close") if @close_scheduled
      return unless data
      data = data.to_java_bytes if data.is_a?(String) # EM compat
      buffer = ByteBuffer.wrap(data)
      if buffer.has_remaining
        @outbound_queue << buffer
      end
    end

    def write_outbound_data
      while can_send?
        buffer = @outbound_queue.first
        @socket.write(buffer) if buffer.has_remaining
        # Did we consume the whole outbound buffer? If yes,
        # pop it off and keep looping. If no, the outbound network
        # buffers are full, so break out of here.
        if buffer.remaining == 0
          @outbound_queue.shift
        else
          break
        end
      end

      if can_send?
        # network buffers are full
        return false
      end

      close if @close_scheduled
      return true
    end

    def close(after_writing = false)
      super
      @socket.close unless can_send?
    end

    def closed?
      @socket.socket.closed?
    end

    def peer
      [@socket.socket.port, @socket.socket.inet_address.host_address]
    end

  end
end
