require 'zmachine/jeromq-0.3.2-SNAPSHOT.jar'
java_import org.zeromq.ZMsg
java_import org.zeromq.ZMQ
java_import org.zeromq.ZMQException

require 'zmachine'
require 'zmachine/channel'

class ZMQ
  class Socket
    # for performance reason we alias the method here (otherwise it uses reflections all the time!)
    # super ugly, since we need to dynamically infer the java class of byte[]
    java_alias :send_byte_buffer, :sendByteBuffer, [Java::JavaNio::ByteBuffer.java_class, Java::int]
    java_alias :send_byte_array, :send, [[].to_java(:byte).java_class, Java::int]
    java_alias :recv_byte_array, :recv, [Java::int]

    def write(buffer)
      bytes = send_byte_buffer(buffer, 0)
      buffer.position(buffer.position + bytes)
    end
  end
end

module ZMachine
  class ZMQChannel < Channel

    extend Forwardable

    def_delegator :@socket, :identity
    def_delegator :@socket, :identity=

    def selectable_fd
      @socket.fd
    end

    def bind(address, type)
      ZMachine.logger.debug("zmachine:zmq_channel:#{__method__}", channel: self) if ZMachine.debug
      @bound = true
      @connected = true
      @socket = ZMachine.context.create_socket(type)
      @socket.bind(address)
    end

    def bound?
      @bound
    end

    def accept
      ZMachine.logger.debug("zmachine:zmq_channel:#{__method__}", channel: self) if ZMachine.debug
      self
    end

    def connect(address, type)
      ZMachine.logger.debug("zmachine:zmq_channel:#{__method__}", channel: self) if ZMachine.debug
      @connection_pending = true
      @socket = ZMachine.context.create_socket(type)
      @socket.connect(address)
    end

    def connection_pending?
      @connection_pending
    end

    def finish_connecting
      ZMachine.logger.debug("zmachine:zmq_channel:#{__method__}", channel: self) if ZMachine.debug
      return unless connection_pending?
      @connected = true
    end

    def connected?
      @connected
    end

    def read_inbound_data(raw = false)
      ZMachine.logger.debug("zmachine:zmq_channel:#{__method__}", channel: self) if ZMachine.debug
      data = ZMsg.recv_msg(@socket)
      data = String.from_java_bytes(data.first.data) unless raw
      data
    end

    def send1(a)
      @socket.send_byte_array(a, ZMQ::DONTWAIT)
    end

    def send2(a, b)
      @socket.send_byte_array(a, ZMQ::SNDMORE | ZMQ::DONTWAIT) and
      @socket.send_byte_array(b, ZMQ::DONTWAIT)
    end

    def send3(a, b, c)
      @socket.send_byte_array(a, ZMQ::SNDMORE | ZMQ::DONTWAIT) and
      @socket.send_byte_array(b, ZMQ::SNDMORE | ZMQ::DONTWAIT) and
      @socket.send_byte_array(c, ZMQ::DONTWAIT)
    end

    def send4(a, b, c, d)
      @socket.send_byte_array(a, ZMQ::SNDMORE | ZMQ::DONTWAIT) and
      @socket.send_byte_array(b, ZMQ::SNDMORE | ZMQ::DONTWAIT) and
      @socket.send_byte_array(c, ZMQ::SNDMORE | ZMQ::DONTWAIT) and
      @socket.send_byte_array(d, ZMQ::DONTWAIT)
    end

    def close!
      ZMachine.logger.debug("zmachine:zmq_channel:#{__method__}", channel: self) if ZMachine.debug
      @closed = true
      @connected = false
      @bound = false
      ZMachine.context.destroySocket(@socket)
    end

    def closed?
      @closed
    end

    def peer
      raise RuntimeError.new("ZMQChannel has no peer")
    end

    # see comment in ConnectionManager#process
    def can_recv?
      @socket.events & ZMQ::Poller::POLLIN == ZMQ::Poller::POLLIN
    end

  end
end
