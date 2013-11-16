java_import java.nio.ByteBuffer

module ZMachine
  class Channel

    attr_accessor :socket

    def initialize
      @inbound_buffer = ByteBuffer.allocate(1024 * 1024)
      @outbound_queue = []
      @close_scheduled = false
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

    def close(after_writing = false)
      ZMachine.logger.debug("zmachine:channel:#{__method__}", channel: self, after_writing: after_writing) if ZMachine.debug
      @close_scheduled = true
      @outbound_queue.clear unless after_writing
    end

    def close_after_writing
      close(true)
    end

  end
end
