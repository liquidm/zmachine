java_import java.nio.ByteBuffer

module ZMachine
  class Channel

    attr_accessor :socket
    attr_accessor :raw

    def initialize
      @inbound_buffer = ByteBuffer.allocate(1024 * 1024)
      @outbound_queue = []
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
      !@outbound_queue.empty?
    end

    def send_data(data)
      ZMachine.logger.debug("zmachine:channel:#{__method__}", channel: self) if ZMachine.debug
      raise RuntimeError.new("send_data called after close") if @closed_callback
      return unless data
      buffer = ByteBuffer.wrap(data)
      if buffer.has_remaining
        @outbound_queue << buffer
      end
    end

    def write_outbound_data
      ZMachine.logger.debug("zmachine:channel:#{__method__}", channel: self, can_send: can_send?) if ZMachine.debug
      while can_send?
        buffer = @outbound_queue.first
        @socket.write(buffer) if buffer.has_remaining
        # Did we consume the whole outbound buffer? If yes,
        # pop it off and keep looping. If no, the outbound network
        # buffers are full, so break out of here.
        break if buffer.has_remaining
        @outbound_queue.shift
      end
      maybe_close_with_callback
    end

    def close(after_writing = false, &block)
      return true if closed?
      ZMachine.logger.debug("zmachine:channel:#{__method__}", channel: self, after_writing: after_writing, caller: caller[0].inspect) if ZMachine.debug
      @close_scheduled = true
      @closed_callback = block if block
      @outbound_queue.clear unless after_writing
      maybe_close_with_callback
    end

    def maybe_close_with_callback
      ZMachine.logger.debug("zmachine:channel:#{__method__}", channel: self, can_send: can_send?) if ZMachine.debug
      return false if can_send?
      return true unless @close_scheduled
      close!
      @closed_callback.call if @closed_callback
      return true
    end

  end
end
