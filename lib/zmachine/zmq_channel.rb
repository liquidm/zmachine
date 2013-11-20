require 'zmachine/jeromq-0.3.0-SNAPSHOT.jar'
java_import org.zeromq.ZMQ
java_import org.zeromq.ZMQException

require 'zmachine'
require 'zmachine/channel'

class ZMQ
  class Socket
    # for performance reason we alias the method here (otherwise it uses reflections all the time!)
    # super ugly, since we need to dynamically infer the java class of byte[]
    java_alias :send_byte_array, :send, [[].to_java(:byte).java_class, Java::int]
    java_alias :recv_byte_array, :recv, [Java::int]
  end
end

module ZMachine
  class ZMQChannel < Channel

    def initialize(type)
      super()
      @socket = ZMachine.context.create_socket(type)
      @bound = false
      @connected = false
      @closed = false
    end

    def identity=(v)
      @socket.identity = v if @socket
    end
    def identity
      @socket ? @socket.identity : nil
    end

    def selectable_fd
      @socket.fd
    end

    def bind(address, port = nil)
      @bound = true
      @socket.bind(address)
    end

    def bound?
      @bound
    end

    def connect(address)
      @connected = true
      @socket.connect(address)
    end

    def connection_pending?
      false
    end

    def connected?
      @connected
    end

    def read_inbound_data
      data = [@socket.recv_byte_array(0)]
      while @socket.hasReceiveMore
        data << @socket.recv_byte_array(0)
      end
      data
    end

    def send_data(data)
      parts, last = data[0..-2], data.last
      parts.each do |part|
        @socket.send_byte_array(part, ZMQ::SNDMORE | ZMQ::DONTWAIT)
      end
      @socket.send_byte_array(last, ZMQ::DONTWAIT)
    rescue ZMQException
      @outbound_queue << data
    end

    # to get around iterating over an array in #send_data we pass message parts
    # as arguments
    def send1(a)
      @socket.send_byte_array(a, ZMQ::DONTWAIT)
    end

    def send2(a, b)
      @socket.send_byte_array(a, ZMQ::SNDMORE | ZMQ::DONTWAIT)
      @socket.send_byte_array(b, ZMQ::DONTWAIT)
    end

    def send3(a, b, c)
      @socket.send_byte_array(a, ZMQ::SNDMORE | ZMQ::DONTWAIT)
      @socket.send_byte_array(b, ZMQ::SNDMORE | ZMQ::DONTWAIT)
      @socket.send_byte_array(c, ZMQ::DONTWAIT)
    end

    def send4(a, b, c, d)
      @socket.send_byte_array(a, ZMQ::SNDMORE | ZMQ::DONTWAIT)
      @socket.send_byte_array(b, ZMQ::SNDMORE | ZMQ::DONTWAIT)
      @socket.send_byte_array(c, ZMQ::SNDMORE | ZMQ::DONTWAIT)
      @socket.send_byte_array(d, ZMQ::DONTWAIT)
    end

    def has_more?
      @socket.events & ZMQ::Poller::POLLIN == ZMQ::Poller::POLLIN
    end

    def can_send?
      super and (@socket.events & ZMQ::Poller::POLLOUT == ZMQ::Poller::POLLOUT)
    end

    def write_outbound_data
      while can_send?
        data = @outbound_queue.shift
        send_data(data)
      end

      close if @close_scheduled
      return true
    end

    def close(after_writing = false)
      super
      @closed = true
      @connected = false
      @bound = false
      ZMachine.context.destroySocket(@socket) unless can_send?
    end

    def closed?
      @closed
    end

    def peer
      raise RuntimeError.new("ZMQChannel has no peer")
    end

  end
end
