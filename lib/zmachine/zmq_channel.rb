require 'zmachine'
require 'zmachine/channel'

module ZMachine
  class ZMQChannel < Channel

    extend Forwardable

    def_delegator :@socket, :identity
    def_delegator :@socket, :identity=

    def initialize
      super
      @raw = true
    end

    def selectable_fd
      @socket.fd
    end

    def bind(address, type)
      ZMachine.logger.debug("zmachine:zmq_channel:#{__method__}", channel: self) if ZMachine.debug
      @bound = true
      @connected = true
      @socket = ZContext.create_socket(type)
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
      @socket = ZContext.create_socket(type)
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

    def read_inbound_data
      ZMachine.logger.debug("zmachine:zmq_channel:#{__method__}", channel: self) if ZMachine.debug
      return nil unless can_recv?
      data = ZMsg.recv_msg(@socket)
      data = String.from_java_bytes(data.first.data) unless @raw
      data
    end

    def close!
      ZMachine.logger.debug("zmachine:zmq_channel:#{__method__}", channel: self) if ZMachine.debug
      @closed = true
      @connected = false
      @bound = false
      ZContext.destroy_socket(@socket)
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
