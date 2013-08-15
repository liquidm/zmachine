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

    def send_data(d1, d2, d3, d4)
      # (troll)
      flags = ZMQ::SNDMORE | ZMQ::DONTWAIT
      flags &= ~ZMQ::SNDMORE unless d2
      puts "send_data(): #{d1.inspect}, #{flags.inspect}"
      @socket.send(d1.to_java_bytes, flags)
      return if flags & ZMQ::SNDMORE == 0
      flags &= ~ZMQ::SNDMORE unless d3
      puts "send_data(): #{d2.inspect}, #{flags.inspect}"
      @socket.send(d2.to_java_bytes, flags)
      return if flags & ZMQ::SNDMORE == 0
      flags &= ~ZMQ::SNDMORE unless d4
      puts "send_data(): #{d3.inspect}, #{flags.inspect}"
      @socket.send(d3.to_java_bytes, flags)
      return if flags & ZMQ::SNDMORE == 0
      flags &= ~ZMQ::SNDMORE
      puts "send_data(): #{d4.inspect}, #{flags.inspect}"
      @socket.send(d4.to_java_bytes, flags)
    end

    def read_inbound_data(buffer)
      return if @socket.events & ZMQ::Poller::POLLIN == 0
      data = []
      loop do
        data << String.from_java_bytes(@socket.recv)
        break unless @socket.has_receive_more
      end
      data
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
