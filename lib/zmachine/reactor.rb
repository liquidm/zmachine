java_import java.io.FileDescriptor
java_import java.io.IOException
java_import java.net.InetSocketAddress
java_import java.nio.ByteBuffer
java_import java.nio.channels.ClosedChannelException
java_import java.nio.channels.SelectionKey
java_import java.nio.channels.Selector
java_import java.nio.channels.ServerSocketChannel
java_import java.nio.channels.SocketChannel
java_import java.util.TreeMap
java_import java.util.concurrent.atomic.AtomicBoolean
java_import java.util.concurrent.ConcurrentLinkedQueue

require 'zmachine/jeromq-0.3.0-SNAPSHOT.jar'
java_import org.zeromq.ZContext

require 'zmachine/acceptor'
require 'zmachine/tcp_channel'
require 'zmachine/zmq_channel'

module ZMachine

  class NotReactorOwner < Exception
  end

  class NoReactorError < Exception
  end

  class Reactor

    @mutex = Mutex.new

    def self.register_reactor(reactor)
      @mutex.synchronize do
        @reactors ||= []
        @reactors << reactor
      end
    end

    def self.terminate_all_reactors
      # should have a lock ....
      @mutex.synchronize do
        @reactors.each(&:stop_event_loop)
        @reactors.clear
      end
    end

    def self.unregister_reactor(reactor)
      @mutex.synchronize do
        @reactors.delete(reactor)
      end
    end

    def initialize
      @timers = TreeMap.new
      @timer_callbacks = {}
      @channels = []
      @new_channels = []
      @unbound_channels = []
      @next_signature = 0
      @shutdown_hooks = []
      @next_tick_queue = ConcurrentLinkedQueue.new
      @running = false

      # don't use a direct buffer. Ruby doesn't seem to like them.
      @read_buffer = ByteBuffer.allocate(32*1024)
    end

    def add_shutdown_hook(&block)
      @shutdown_hooks << block
    end

    def add_timer(*args, &block)
      check_reactor_thread
      interval = args.shift
      callback = args.shift || block
      return unless callback

      signature = next_signature
      deadline = java.lang.System.nano_time + (interval.to_f * 1000_000_000).to_i

      if @timers.contains_key(deadline)
        @timers.get(deadline) << signature
      else
        @timers.put(deadline, [signature])
      end

      ZMachine.logger.debug("zmachine:#{__method__}", signature: signature) if ZMachine.debug
      @timer_callbacks[signature] = callback
      signature
    end

    def cancel_timer(timer_or_sig)
      if timer_or_sig.respond_to?(:cancel)
        timer_or_sig.cancel
      else
        ZMachine.logger.debug("zmachine:#{__method__}", signature: timer_or_sig) if ZMachine.debug
        @timer_callbacks[timer_or_sig] = false if @timer_callbacks.has_key?(timer_or_sig)
      end
    end

    def connect(server, port_or_type=nil, handler=nil, *args, &block)
      ZMachine.logger.debug("zmachine:#{__method__}", server: server, port_or_type: port_or_type) if ZMachine.debug
      check_reactor_thread
      if server.nil? or server =~ %r{\w+://}
        _connect_zmq(server, port_or_type, handler, *args, &block)
      else
        _connect_tcp(server, port_or_type, handler, *args, &block)
      end
    end

    def reconnect(server, port, handler)
      # No reconnect for zmq ... handled by zmq itself anyway
      return if handler && handler.channel.is_a?(ZMQChannel) #
      # TODO : we might want to check if this connection is really dead?
      connect server, port, handler
    end

    def connection_count
      @channels.size
    end

    def error_handler(callback = nil, &block)
      @error_handler = callback || block
    end

    def next_tick(callback=nil, &block)
      @next_tick_queue << (callback || block)
      signal_loopbreak if reactor_running?
    end

    def run(callback=nil, shutdown_hook=nil, &block)
      ZMachine.logger.debug("zmachine:#{__method__}") if ZMachine.debug

      @callback = callback || block

      add_shutdown_hook(shutdown_hook) if shutdown_hook

      begin
        # list of active reactors
        Reactor.register_reactor(self)

        @running = true

        if @callback
          add_timer(0) do
            @callback.call(self)
          end
        end

        @selector = Selector.open
        @run_reactor = true

        while @run_reactor
          ZMachine.logger.debug("zmachine:#{__method__}", run_reactor: true) if ZMachine.debug
          run_deferred_callbacks
          break unless @run_reactor
          run_timers
          break unless @run_reactor
          remove_unbound_channels
          check_io
          add_new_channels
          process_io
        end
      rescue => e
        # maybe add error check callback here
        puts "FATAL reactor died : #{e.message}"
        puts e.backtrace
      ensure
        ZMachine.logger.debug("zmachine:#{__method__}", stop: :selector) if ZMachine.debug
        @selector.close rescue nil
        @selector = nil
        ZMachine.logger.debug("zmachine:#{__method__}", stop: :channels) if ZMachine.debug
        @unbound_channels += @channels
        remove_unbound_channels
        ZMachine.logger.debug("zmachine:#{__method__}", stop: :shutdown_hooks) if ZMachine.debug
        @shutdown_hooks.pop.call until @shutdown_hooks.empty?
        @next_tick_queue = ConcurrentLinkedQueue.new
        @running = false
        Reactor.unregister_reactor(self)
        ZMachine.logger.debug("zmachine:#{__method__}", stop: :zcontext) if ZMachine.debug
        ZMachine.context.destroy
      end
    end

    def reactor_running?
      @running || false
    end

    def start_server(server, port_or_type=nil, handler=nil, *args, &block)
      ZMachine.logger.debug("zmachine:#{__method__}", server: server, port_or_type: port_or_type) if ZMachine.debug
      if server =~ %r{\w+://}
        _bind_zmq(server, port_or_type, handler, *args, &block)
      else
        _bind_tcp(server, port_or_type, handler, *args, &block)
      end
    end

    def stop_event_loop
      @run_reactor = false
      signal_loopbreak
    end

    def stop_server(channel)
      channel.close
    end

    private

    def check_reactor_thread
      raise NoReactorError if !Thread.current[:reactor]
      raise NotReactorOwner if Thread.current[:reactor] != self
    end


    def _bind_tcp(address, port, handler, *args, &block)
      klass = _klass_from_handler(Connection, handler)
      channel = TCPChannel.new(@selector)
      channel.bind(address, port)
      add_channel(channel, Acceptor, klass, *args, &block)
    end

    def _bind_zmq(address, type, handler, *args, &block)
      klass = _klass_from_handler(Connection, handler)
      channel = ZMQChannel.new(type, @selector)
      channel.bind(address)
      add_channel(channel, klass, *args, &block)
    end

    def _connect_tcp(address, port, handler=nil, *args, &block)
      klass = _klass_from_handler(Connection, handler)
      channel = TCPChannel.new(@selector)
      channel.connect(address, port)
      channel.connect_pending = true
      add_channel(channel, klass, *args, &block)
      channel.handler
    end

    def _connect_zmq(address, type, handler=nil, *args, &block)
      klass = _klass_from_handler(Connection, handler)
      channel = ZMQChannel.new(type, @selector)
      add_channel(channel, klass, *args, &block)
      channel.connect(address)
      channel.handler.connection_completed
      channel.handler
    end

    def check_io
      if @new_channels.size > 0
        timeout = -1
      elsif !@timers.empty?
        now = java.lang.System.nano_time
        timer_key = @timers.first_key
        timeout = (timer_key - now) / 1_000_000 # needed in ms ... we are in nanos
        timeout = -1 if timeout <= 0
      else
        timeout = 0
      end

      if @channels.any?(&:has_more?)
        timeout = -1
      end

      ZMachine.logger.debug("zmachine:#{__method__}", timeout: timeout) if ZMachine.debug

      if timeout == -1
        @selector.select_now
      else
        @selector.select(timeout)
      end
    end

    def process_io
      it = @selector.selected_keys.iterator

      while it.has_next
        selected_key = it.next
        it.remove
        if selected_key.connectable?
          is_connectable(selected_key.attachment)
        elsif selected_key.acceptable?
          is_acceptable(selected_key.attachment)
        else
          is_writable(selected_key.attachment) if selected_key.writable?
          is_readable(selected_key.attachment) if selected_key.readable?
        end
      end

      @channels.each do |channel|
        is_readable(channel) if channel.has_more?
        is_writable(channel) if channel.can_send?
      end
    end

    def is_acceptable(channel)
      ZMachine.logger.debug("zmachine:#{__method__}", channel: channel) if ZMachine.debug
      client_channel = channel.accept(next_signature)
      acceptor = channel.handler
      add_channel(client_channel, acceptor.klass, *acceptor.args, &acceptor.callback)
    rescue IOException
      channel.close
    end

    def is_readable(channel)
      ZMachine.logger.debug("zmachine:#{__method__}", channel: channel) if ZMachine.debug
      data = channel.read_inbound_data(@read_buffer)
      channel.handler.receive_data(data) if data
    rescue IOException
      @unbound_channels << channel
    end

    def is_writable(channel)
      ZMachine.logger.debug("zmachine:#{__method__}", channel: channel) if ZMachine.debug
      @unbound_channels << channel unless channel.write_outbound_data
    rescue IOException
      @unbound_channels << channel
    end

    def is_connectable(channel)
      ZMachine.logger.debug("zmachine:#{__method__}", channel: channel) if ZMachine.debug
      result = channel.finish_connecting
      # we need to handle this properly, not just log it
      ZMachine.logger.warn("zmachine:finish_connecting failed", channel: channel) if !result
      channel.handler.connection_completed
    rescue IOException
      @unbound_channels << channel
    end

    def add_channel(channel, klass_or_instance, *args, &block)
      ZMachine.logger.debug("zmachine:#{__method__}", channel: channel) if ZMachine.debug
      if klass_or_instance.is_a?(Connection)
        # if klass_or_instance is not a class but already an instance
        channel.handler = klass_or_instance
        klass_or_instance.channel = channel
      else
        channel.handler = klass_or_instance.new(channel, *args)
      end
      @new_channels << channel
      block.call(channel.handler) if block
      channel
    rescue => e
      puts "ERROR adding channel #{e.message}"
      puts e.backtrace
    end

    def add_new_channels
      @new_channels.each do |channel|
        begin
          channel.register
          @channels << channel
        rescue ClosedChannelException => e
          puts "ERROR adding channel #{e.message}"
          puts e.backtrace
          @unbound_channels << channel
        end
      end
      @new_channels.clear
    end

    def remove_unbound_channels
      @unbound_channels.each do |channel|
        channel.handler.unbind if channel.handler
        channel.close
      end
      @unbound_channels.clear
    end

    def run_deferred_callbacks
      # max is current size
      size = @next_tick_queue.size
      while size > 0 && callback = @next_tick_queue.poll
        begin
          size -= 1
          callback.call
        ensure
          ZMachine.next_tick {} if $!
        end
      end
    end

    # TODO : we should definitly optimize periodic timers ... right now they are wasting a hell of cycle es they are recreated on every invocation
    def run_timers
      now = java.lang.System.nano_time
      until @timers.empty?
        timer_key = @timers.first_key
        break if timer_key > now
        signatures = @timers.get(timer_key)
        @timers.remove(timer_key)
        # Fire all timers at this timestamp
        signatures.each do |signature|
          callback = @timer_callbacks.delete(signature)
          return if callback == false # callback cancelled
          callback or raise UnknownTimerFired, "callback data: #{signature}"
          callback.call
        end
      end
    end

    def signal_loopbreak
      @selector.wakeup if @selector
    end

    def next_signature
      @next_signature += 1
    end

    def _klass_from_handler(klass = Connection, handler = nil)
      if handler and handler.is_a?(Class)
        handler
      elsif handler and handler.is_a?(Connection)
        # can happen on reconnect
        handler
      elsif handler
        # MK : this method does not exist?!
        # _handler_from_klass(klass, handler)
        raise "please check, not implemented"
      else
        klass
      end
    end

    def _handler_from_module(klass, handler)
      handler::CONNECTION_CLASS
    rescue NameError
      handler::const_set(:CONNECTION_CLASS, Class.new(klass) { include handler })
    end

  end
end
