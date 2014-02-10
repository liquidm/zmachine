java_import java.io.IOException
java_import java.nio.ByteBuffer
java_import java.nio.channels.SelectionKey

require 'zmachine'

module ZMachine
  class Connection

    extend Forwardable

    attr_accessor :channel
    attr_reader :timer

    def self.new(*args)
      allocate.instance_eval do
        initialize(*args)
        @args = args
        post_init
        self
      end
    end

    # channel type dispatch

    def bind(address, port_or_type, &block)
      ZMachine.logger.debug("zmachine:connection:#{__method__}", connection: self) if ZMachine.debug
      klass = (address =~ %r{\w+://}) ? ZMQChannel : TCPChannel
      @channel = klass.new
      @channel.bind(address, port_or_type)
      @block = block
      @block.call(self) if @block && @channel.is_a?(ZMQChannel)
      self
    end

    def connect(address, port_or_type, &block)
      ZMachine.logger.debug("zmachine:connection:#{__method__}", connection: self) if ZMachine.debug
      klass = (address.nil? || address =~ %r{\w+://}) ? ZMQChannel : TCPChannel
      @channel = klass.new
      @channel.connect(address, port_or_type) if address
      yield self if block_given?
      renew_timer
      self
    end

    # callbacks
    def connection_accepted
    end

    def connection_completed
    end

    def post_init
    end

    def receive_data(data)
    end

    def unbind
    end

    # EventMachine Connection API

    def_delegator :@channel, :bound?
    def_delegator :@channel, :closed?
    def_delegator :@channel, :connected?
    def_delegator :@channel, :connection_pending?

    def close_connection(after_writing = false)
      @channel.close(after_writing) do
        ZMachine.close_connection(self)
      end
    end

    alias :close :close_connection

    def close_connection_after_writing
      close_connection(true)
    end

    alias :close_after_writing close_connection_after_writing

    def comm_inactivity_timeout
      @inactivity_timeout
    end

    def comm_inactivity_timeout=(value)
      @inactivity_timeout = value
    end

    alias :set_comm_inactivity_timeout :comm_inactivity_timeout=

    def get_idle_time
      (System.nano_time - @last_activity) / 1_000_000
    end

    def get_peername
      if peer = @channel.peer
        ::Socket.pack_sockaddr_in(*peer)
      end
    end

    def notify_readable?
      true
    end

    def notify_writable?
      @channel.can_send?
    end

    def pending_connect_timeout=(value)
      @connect_timeout = value
    end

    alias :set_pending_connect_timeout :pending_connect_timeout=

    def reconnect(server, port_or_type)
      ZMachine.reconnect(server, port_or_type, self)
    end

    def send_data(data)
      ZMachine.logger.debug("zmachine:connection:#{__method__}", connection: self) if ZMachine.debug
      data = data.to_java_bytes if data.is_a?(String) # EM compat
      @channel.send_data(data)
      update_events
    end

    # triggers

    def acceptable!
      client = @channel.accept
      ZMachine.logger.debug("zmachine:connection:#{__method__}", connection: self, client: client) if ZMachine.debug
      connection = self.class.new(*@args)
      connection.channel = client
      @block.call(connection) if @block
      connection.connection_accepted
      connection
    end

    def connectable!
      ZMachine.logger.debug("zmachine:connection:#{__method__}", connection: self) if ZMachine.debug
      @channel.finish_connecting
      @timer.cancel if @timer # cancel pending connect timer
      mark_active!
      connection_completed if @channel.connected?
      update_events
      nil
    end

    def readable!
      ZMachine.logger.debug("zmachine:connection:#{__method__}", connection: self) if ZMachine.debug
      mark_active!
      data = @channel.read_inbound_data
      receive_data(data) if data
      nil
    end

    def writable!
      ZMachine.logger.debug("zmachine:connection:#{__method__}", connection: self) if ZMachine.debug
      mark_active!
      @channel.write_outbound_data
      update_events
      nil
    end

    # selector registration

    def register(selector)
      ZMachine.logger.debug("zmachine:connection:#{__method__}", connection: self, fd: @channel.selectable_fd) if ZMachine.debug
      @channel_key = @channel.selectable_fd.register(selector, current_events, self)
    end

    def valid?
      @channel_key &&
      @channel_key.valid?
    end

    def update_events
      return unless valid?
      ZMachine.logger.debug("zmachine:connection:#{__method__}", connection: self) if ZMachine.debug
      @channel_key.interest_ops(current_events)
    end

    def current_events
      if @channel.is_a?(ZMQChannel)
        return SelectionKey::OP_READ
      end

      if bound?
        return SelectionKey::OP_ACCEPT
      end

      if connection_pending?
        return SelectionKey::OP_CONNECT
      end

      events = 0

      events |= SelectionKey::OP_READ if notify_readable?
      events |= SelectionKey::OP_WRITE if notify_writable?

      return events
    end

    def process_events
      return unless valid?
      ZMachine.logger.debug("zmachine:connection:#{__method__}", connection: self) if ZMachine.debug
      if @channel_key.connectable?
        connectable!
      elsif @channel_key.acceptable?
        acceptable!
      else
        writable! if @channel_key.writable?
        readable! if @channel_key.readable?
      end
    rescue Java::JavaNioChannels::CancelledKeyException
      # channel may have been closed by write handler. ignore exception and
      # wait for cleanup
    end

    def mark_active!
      @last_activity = System.nano_time
      renew_timer if @inactivity_timeout
    end

    def renew_timer
      @timer.cancel if @timer
      if connection_pending? && @connect_timeout
        @timer = ZMachine.add_timer(@connect_timeout) { ZMachine.close_connection(self, Errno::ETIMEDOUT) }
      elsif @inactivity_timeout
        @timer = ZMachine.add_timer(@inactivity_timeout) { ZMachine.close_connection(self, Errno::ETIMEDOUT) }
      end
    end

  end
end
