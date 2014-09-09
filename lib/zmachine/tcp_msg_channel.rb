java_import java.io.IOException
java_import java.net.InetSocketAddress
java_import java.nio.channels.SocketChannel
java_import java.nio.channels.ServerSocketChannel

require 'zmachine/channel'

module ZMachine
  class TcpMsgChannel < TCPChannel

    MAGIC = ".lqm".freeze

    def initialize
      super
      @raw = true
      @buffer = Thread.current[:tcp_channel_buffer] ||= ByteBuffer.allocate(1024 * 1024)
    end

    def accept
      ZMachine.logger.debug("zmachine:tcp_msg_channel:#{__method__}", channel: self) if ZMachine.debug
      client_socket = @socket.accept
      return unless client_socket
      client_socket.configure_blocking(false)
      channel = TcpMsgChannel.new
      channel.socket = client_socket
      channel
    end

    # return nil if no addional data is available
    def read_inbound_data
      ZMachine.logger.debug("zmachine:tcp_msg_channel:#{__method__}", channel: self) if ZMachine.debug
      raise IOException.new("EOF") if @socket.read(@buffer) == -1

      @buffer.mark
      @buffer.flip

      # validate magic
      if @buffer.remaining >= 4
        bytes = java.util.Arrays.copyOfRange(@buffer.array, @buffer.position, @buffer.position+4)
        @buffer.position(@buffer.position+4)
        if String.from_java_bytes(bytes) != MAGIC # read broken message - client should reconnect
          ZMachine.logger.error("read broken message", worker: self)
          close!
          return
        end
      else
        @buffer.reset.limit(@buffer.capacity)
        return
      end

      # extract number of msg parts
      if @buffer.remaining >= 4
        bytes = java.util.Arrays.copyOfRange(@buffer.array, @buffer.position, @buffer.position+4)
        @buffer.position(@buffer.position+4)
        array_length = String.from_java_bytes(bytes).unpack('V')[0]
      else
        @buffer.reset.limit(@buffer.capacity)
        return
      end

      # extract data
      data = Array.new(array_length)

      array_length.times do |i|
        if @buffer.remaining >= 4
          bytes = java.util.Arrays.copyOfRange(@buffer.array, @buffer.position, @buffer.position+4)
          @buffer.position(@buffer.position+4)
          data_length = String.from_java_bytes(bytes).unpack('V')[0]
        else
          @buffer.reset.limit(@buffer.capacity)
          return
        end

        if @buffer.remaining >= data_length
          data[i] = java.util.Arrays.copyOfRange(@buffer.array, @buffer.position, @buffer.position+data_length)
          @buffer.position(@buffer.position+data_length)
        else
          @buffer.reset.limit(@buffer.capacity)
          return
        end
      end

      # clear buffer
      if @buffer.remaining
        @buffer.clear
      else
        bytes = java.util.Arrays.copyOfRange(@buffer.array, @buffer.position, @buffer.position+@buffer.remaining)
        @buffer.clear
        @buffer.put(bytes)
      end

      data
    end

  end
end
