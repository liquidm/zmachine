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
      @socket.send(d1, flags)
      return unless flags & ZMQ::SNDMORE
      flags &= ~ZMQ::SNDMORE unless d3
      @socket.send(d2, flags)
      return unless flags & ZMQ::SNDMORE
      flags &= ~ZMQ::SNDMORE unless d4
      @socket.send(d3, flags)
      return unless flags & ZMQ::SNDMORE
      flags &= ~ZMQ::SNDMORE
      @socket.send(d4, flags)
    end

    def read_inbound_data(buffer)
      raise IOException.new("eof") if @selectable_channel.read(buffer) == -1
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
