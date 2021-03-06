java_import 'java.nio.ByteBuffer'
java_import 'java.util.concurrent.ConcurrentLinkedQueue'

module ZMachine
  class Channel

    attr_accessor :socket
    attr_accessor :raw

    def initialize
      @outbound_queue = ConcurrentLinkedQueue.new
      @raw = false
    end

    # methods that need to be implemented in sub classes:
    #
    # selectable_fd
    # bind(address, port = nil)
    # bound?
    # accept
    # connect(address, port = nil)
    # connection_pending?
    # finish_connecting
    # connected?
    # read_inbound_data
    # send_data(data)
    # closed?
    # peer
    # write_outbound_data

    def can_send?
      connected? && !@outbound_queue.empty?
    end

    def more?
      false
    end

    def send_data(data)
      ZMachine.logger.debug("zmachine:channel:#{__method__}", channel: self) if ZMachine.debug
      raise RuntimeError.new("send_data called after close") if @closed_callback
      return unless data
      buffer = ByteBuffer.wrap(data)
      if buffer.has_remaining
        @outbound_queue.add(buffer)
      end
    end

    def write_outbound_data
      ZMachine.logger.debug("zmachine:channel:#{__method__}", channel: self, can_send: can_send?) if ZMachine.debug
      while can_send?
        buffer = @outbound_queue.peek
        break unless buffer
        @socket.write(buffer) if buffer.has_remaining
        # Did we consume the whole outbound buffer? If yes,
        # pop it off and keep looping. If no, the outbound network
        # buffers are full, so break out of here.
        break if buffer.has_remaining
        @outbound_queue.poll
      end
    end

    def close
      return true if closed?
      ZMachine.logger.debug("zmachine:channel:#{__method__}", channel: self, caller: caller[0].inspect) if ZMachine.debug
      @outbound_queue.clear
      close!
    end

  end
end
