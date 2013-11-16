java_import org.zeromq.ZMQ
java_import org.zeromq.ZMsg
java_import org.zeromq.ZMQException

require 'zmachine/channel'

class ZMsg
  # for performance reason we alias the method here (otherwise it uses reflections all the time!)
  java_alias :post, :send, [org.zeromq.ZMQ::Socket, Java::boolean]
end

# this needs to be moved to a seperate file
class ZMQ
  class Socket
    def self.create_socket_with_opts(type, opts = {})
      socket = ZMachine.context.create_socket(type)
      socket.setLinger(opts[:linger]) if opts[:linger]
      socket.setSndHWM(opts[:sndhwm]) if opts[:sndhwm]
      socket.setRcvHWM(opts[:rcvhwm]) if opts[:rcvhwm]
      socket.set_router_mandatory(true) if type == ZMQ::ROUTER
      socket.connect(opts[:connect]) if opts[:connect]
      socket.bind(opts[:bind]) if opts[:bind]
      socket
    end

    def self.pair(opts = {})
      create_socket_with_opts(ZMQ::PAIR, opts)
    end
    def self.router(opts = {})
      create_socket_with_opts(ZMQ::ROUTER, opts)
    end
    def self.pull(opts = {})
      create_socket_with_opts(ZMQ::PULL, opts)
    end
    def self.push(opts = {})
      create_socket_with_opts(ZMQ::PUSH, opts)
    end
    def self.dealer(opts = {})
      create_socket_with_opts(ZMQ::DEALER, opts)
    end
    def self.pub(opts = {})
      create_socket_with_opts(ZMQ::PUB, opts)
    end

    def send2(a,b)
      sent =  send a, ZMQ::SNDMORE | ZMQ::DONTWAIT
      sent &= send b, ZMQ::DONTWAIT
      sent
    end

    def send3(a,b,c)
      sent =  send a, ZMQ::SNDMORE | ZMQ::DONTWAIT
      sent &= send b, ZMQ::SNDMORE | ZMQ::DONTWAIT
      sent &= send c, ZMQ::DONTWAIT
      sent
    end
  end
end

module ZMachine
  class ZMQChannel < Channel

    attr_reader :port
    attr_reader :socket

    def initialize(type, selector)
      super(selector)
      @socket = ZMQChannel.create_socket_with_opts type, linger: 0
    end

    def self.create_socket_with_opts(type, opts = {})
      socket = ZMachine.context.create_socket(type)
      socket.setLinger(opts[:linger]) if opts[:linger]
      socket.setSndHWM(opts[:sndhwm]) if opts[:sndhwm]
      socket.setRcvHWM(opts[:rcvhwm]) if opts[:rcvhwm]
      socket.set_router_mandatory(true) if type == ZMQ::ROUTER
      socket.connect(opts[:connect]) if opts[:connect]
      socket.bind(opts[:bind]) if opts[:bind]
      socket
    end

    def register
      @channel_key ||= @socket.fd.register(@selector, current_events, self)
    end

    def bind(address)
      @port = @socket.bind(address)
    end

    def connect(address)
      @socket.connect(address) if address
    end

    def identity=(value)
      @socket.identity = value.to_java_bytes
    end

    def close
      if @channel_key
        @channel_key.cancel
        @channel_key = nil
      end
    end

    def send_data(data)
      @outbound_queue << data unless send_msg(data)
    end

    def send2(a,b)
      @socket.send2 a,b
    end

    def send3(a,b,c)
      @socket.send3 a,b,c
    end

    def send_msg(msg)
      msg.post(@socket, true)
      return true
    rescue ZMQException
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
