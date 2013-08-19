java_import org.zeromq.ZMsg

require 'zmachine/channel'

module ZMachine
  class ZMQChannel < Channel

    attr_reader :selectable_channel

    def initialize(socket, signature, selector)
      super
      @selectable_channel = socket.fd
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
      data.java_send(:send, [org.zeromq.ZMQ::Socket], @socket)
    end

    def read_inbound_data(buffer)
      return unless has_more?
      ZMsg.recv_msg(@socket)
    end

    def has_more?
      @socket.events & ZMQ::Poller::POLLIN == ZMQ::Poller::POLLIN
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

    def current_events
      SelectionKey::OP_READ
    end

  end
end
