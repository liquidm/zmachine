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
      ZMachine.logger.debug("zmachine:tcp_channel:#{__method__}", channel: self) if ZMachine.debug
      address = InetSocketAddress.new(address, port)
      @socket = ServerSocketChannel.open
      @socket.configure_blocking(false)
      @socket.bind(address)
    end

    def bound?
      @socket.is_a?(ServerSocketChannel) && @socket.bound?
    end

    def accept
      ZMachine.logger.debug("zmachine:tcp_channel:#{__method__}", channel: self) if ZMachine.debug
      client_socket = @socket.accept
      return unless client_socket
      client_socket.configure_blocking(false)
      TCPChannel.new.tap do |channel|
        channel.socket = client_socket
      end
    end

    def connect(address, port)
      ZMachine.logger.debug("zmachine:tcp_channel:#{__method__}", channel: self) if ZMachine.debug
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
      ZMachine.logger.debug("zmachine:tcp_channel:#{__method__}", channel: self) if ZMachine.debug
      return unless connection_pending?
      @socket.finish_connect
    end

    def connected?
      @socket.connected?
    end

    def read_inbound_data
      ZMachine.logger.debug("zmachine:tcp_channel:#{__method__}", channel: self) if ZMachine.debug
      buffer = @inbound_buffer
      buffer.clear
      raise IOException.new("EOF") if @socket.read(buffer) == -1
      buffer.flip
      return if buffer.limit == 0
      data = buffer.array[buffer.position...buffer.limit]
      data = String.from_java_bytes(data) unless @raw
      data
    end

    def close!
      ZMachine.logger.debug("zmachine:tcp_channel:#{__method__}", channel: self) if ZMachine.debug
      @socket.close
    end

    def closed?
      @socket.socket.closed?
    end

    def peer
      [@socket.socket.port, @socket.socket.inet_address.host_address]
    end

  end
end
