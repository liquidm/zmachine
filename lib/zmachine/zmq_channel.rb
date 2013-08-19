java_import org.zeromq.ZMsg
java_import org.zeromq.ZMQException

require 'zmachine/channel'

module ZMachine
  class ZMQChannel < Channel

    attr_reader :port

    def initialize(type, signature, selector)
      super(signature, selector)
      @socket = ZMachine.context.create_socket(type)
      @socket.set_router_mandatory(true) rescue nil
    end

    def register
      @channel_key ||= @socket.fd.register(@selector, current_events, self)
    end

    def bind(address)
      @port = @socket.bind(address)
    end

    def connect(address)
      @socket.identity = "client".to_java_bytes
      @socket.connect(address)
    end

    def identity=(value)
      @socket.identity = value.to_java_bytes
    end

    def close
      if @channel_key
        @channel_key.cancel
        @channel_key = nil
      end

      @socket.close rescue nil
    end

    def send_data(data)
      @outbound_queue << data unless send_msg(data)
    end

    def send_msg(msg)
      msg.java_send(:send, [org.zeromq.ZMQ::Socket], @socket)
      return true
    rescue ZMQException => e
      return false
    end

    def read_inbound_data(buffer)
      return unless has_more?
      ZMsg.recv_msg(@socket)
    end

    def write_outbound_data
      until @outbound_queue.empty?
        data = @outbound_queue.first
        if send_msg(data)
          @outbound_queue.shift
        else
          break
        end
      end

      return true
    end

    def has_more?
      @socket.events & ZMQ::Poller::POLLIN == ZMQ::Poller::POLLIN
    end

    def can_send?
      @socket.events & ZMQ::Poller::POLLOUT == ZMQ::Poller::POLLOUT
    end

    def schedule_close(after_writing)
      true
    end

    # TODO: fix me
    def peer_name
      sock = @socket.socket
      [sock.port, sock.inet_address.host_address]
    end

    def sock_name
      sock = @socket.socket
      [sock.local_port, sock.local_address.host_address]
    end

    def current_events
      SelectionKey::OP_READ
    end

  end
end
