java_import org.zeromq.ZMsg

module ZMachine
  class ZMQChannel

    attr_reader :selectable_channel
    attr_reader :signature

    def initialize(socket, signature, selector)
      @socket = socket
      @selectable_channel = socket.fd
      @signature = signature
      @selector = selector
    end

    def register
      @channel_key ||= @selectable_channel.register(@selector, SelectionKey::OP_READ, self)
    end

    def close
      if @channel_key
        @channel_key.cancel
        @channel_key = nil
      end

      @socket.close rescue nil
    end

    def cleanup
      @selectable_channel = nil
    end

    def send_data(data)
      puts "send_data(#{data.inspect})"
      data.java_send(:send, [org.zeromq.ZMQ::Socket], @socket)
    end

    def read_inbound_data(buffer)
      return if @socket.events & ZMQ::Poller::POLLIN == 0
      ZMsg.recv_msg(@socket)
    end

    def schedule_close(after_writing)
      true
    end

    def peer_name
      sock = @selectable_channel.socket
      [sock.port, sock.inet_address.host_address]
    end

    def sock_name
      sock = selectable_channel.socket
      [sock.local_port, sock.local_address.host_address]
    end

  end
end
