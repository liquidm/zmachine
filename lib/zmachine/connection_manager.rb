java_import java.nio.channels.ClosedChannelException

require 'zmachine/tcp_channel'
require 'zmachine/zmq_channel'

module ZMachine
  class ConnectionManager

    attr_reader :connections

    def initialize(selector)
      ZMachine.logger.debug("zmachine:connection_manager:#{__method__}") if ZMachine.debug
      @selector = selector
      @connections = []
      @zmq_connections = []
      @new_connections = []
      @unbound_connections = []
    end

    def idle?
      @new_connections.size == 0 and
      @zmq_connections.none? {|c| c.channel.has_more? } # see comment in #process
    end

    def shutdown
      ZMachine.logger.debug("zmachine:connection_manager:#{__method__}") if ZMachine.debug
      @unbound_connections += @connections
      cleanup
    end

    def bind(address, port_or_type, handler, *args, &block)
      ZMachine.logger.debug("zmachine:connection_manager:#{__method__}", address: address, port_or_type: port_or_type) if ZMachine.debug
      connection = build_connection(handler, *args, &block)
      connection.bind(address, port_or_type)
      @new_connections << connection
      connection
    end

    def connect(address, port_or_type, handler, *args, &block)
      ZMachine.logger.debug("zmachine:connection_manager:#{__method__}", address: address, port_or_type: port_or_type) if ZMachine.debug
      connection = build_connection(handler, *args, &block)
      connection.connect(address, port_or_type)
      @new_connections << connection
      yield connection if block_given?
      connection
    rescue java.nio.channels.UnresolvedAddressException
      raise ZMachine::ConnectionError.new('unable to resolve server address')
    end

    def process
      ZMachine.logger.debug("zmachine:connection_manager:#{__method__}") if ZMachine.debug
      add_new_connections
      it = @selector.selected_keys.iterator
      while it.has_next
        process_connection(it.next.attachment)
        it.remove
      end
      # super ugly, but ZMQ only triggers the FD if and only if you have read
      # every message from the socket. under load however there will always be
      # new messages in the mailbox between last recv and next select, which
      # causes the FD never to be triggered again.
      # the only mitigation strategy i came up with is iterating over all channels :(
      @zmq_connections.each do |connection|
        connection.readable! if connection.channel.has_more?
      end
    end

    def process_connection(connection)
      new_connection = connection.process_events
      @new_connections << new_connection if new_connection
    rescue IOException
      close_connection(connection)
    end

    def close_connection(connection)
      ZMachine.logger.debug("zmachine:connection_manager:#{__method__}", connection: connection) if ZMachine.debug
      @unbound_connections << connection
    end

    def add_new_connections
      @new_connections.compact.each do |connection|
        ZMachine.logger.debug("zmachine:connection_manager:#{__method__}", connection: connection) if ZMachine.debug
        begin
          connection.register(@selector)
          @connections << connection
          @zmq_connections << connection if connection.channel.is_a?(ZMQChannel)
        rescue ClosedChannelException => e
          ZMachine.logger.exception(e, "failed to add connection")
          @unbound_connections << connection
        end
      end
      @new_connections.clear
    end

    def cleanup
      return if @unbound_connections.empty?
      ZMachine.logger.debug("zmachine:connection_manager:#{__method__}") if ZMachine.debug
      @unbound_connections.each do |connection|
        reason = nil
        connection, reason = *connection if connection.is_a?(Array)
        begin
          @connections.delete(connection)
          @zmq_connections.delete(connection)
          connection.unbind
          connection.close
        rescue Exception => e
          ZMachine.logger.exception(e, "failed to unbind connection") if ZMachine.debug
        end
      end
      @unbound_connections.clear
    end

    private

    def build_connection(handler, *args, &block)
      if handler and handler.is_a?(Class)
        handler.new(*args, &block)
      elsif handler and handler.is_a?(Connection)
        # already initialized connection on reconnect
        handler
      elsif handler
        connection_from_module(handler).new(*args, &block)
      else
        Connection.new(*args, &block)
      end
    end

    def connection_from_module(handler)
      handler::CONNECTION_CLASS
    rescue NameError
      handler::const_set(:CONNECTION_CLASS, Class.new(Connection) { include handler })
    end

  end
end
