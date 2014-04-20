java_import java.lang.System
java_import java.nio.channels.Selector
java_import java.util.concurrent.ConcurrentLinkedQueue

require 'zmachine/hashed_wheel'
require 'zmachine/connection_manager'

module ZMachine

  class NotReactorOwner < Exception; end
  class NoReactorError < Exception; end

  class Reactor

    @mutex = Mutex.new

    def self.register_reactor(reactor)
      @mutex.synchronize do
        @reactors ||= []
        @reactors << reactor
      end
    end

    def self.terminate_all_reactors
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
      @heartbeat_interval = ZMachine.heartbeat_interval || 0.5 # coarse grained by default
      @next_tick_queue = ConcurrentLinkedQueue.new
      @running = false
      @shutdown_hooks = []
      # a 10 ms tick wheel with 512 slots => ~5s for a round
      @wheel = HashedWheel.new(512, 10)
    end

    def add_shutdown_hook(&block)
      @shutdown_hooks << block
    end

    def add_timer(*args, &block)
      check_reactor_thread
      interval = args.shift
      callback = args.shift || block
      ZMachine.logger.debug("zmachine:reactor:#{__method__}", interval: interval, callback: callback) if ZMachine.debug
      return unless callback
      @wheel.add((interval * 1000).to_i, &callback)
    end

    def bind(server, port_or_type=nil, handler=nil, *args, &block)
      ZMachine.logger.debug("zmachine:reactor:#{__method__}", server: server, port_or_type: port_or_type) if ZMachine.debug
      check_reactor_thread
      @connection_manager.bind(server, port_or_type, handler, *args, &block)
    end

    def close_connection(connection, after_writing = false, reason = nil)
      return true unless @connection_manager
      @connection_manager.close_connection(connection, after_writing, reason)
    end

    def connect(server, port_or_type=nil, handler=nil, *args, &block)
      ZMachine.logger.debug("zmachine:reactor:#{__method__}", server: server, port_or_type: port_or_type) if ZMachine.debug
      check_reactor_thread
      @connection_manager.connect(server, port_or_type, handler, *args, &block)
    end

    def connections
      @connection_manager.connections
    end

    def heartbeat_interval
      @heartbeat_interval
    end

    def heartbeat_interval=(value)
      value = 0.01 if value < 0.01
      @heartbeat_interval = value
    end

    def next_tick(callback=nil, &block)
      @next_tick_queue << (callback || block)
      wakeup if running?
    end

    def reconnect(server, port_or_type, handler)
      return handler if handler && handler.channel.is_a?(ZMQChannel)
      ZMachine.logger.debug("zmachine:reactor:#{__method__}", server: server, port_or_type: port_or_type) if ZMachine.debug
      connect(server, port_or_type, handler)
    end

    def run(callback=nil, shutdown_hook=nil, &block)
      ZMachine.logger.debug("zmachine:reactor:#{__method__}") if ZMachine.debug
      add_shutdown_hook(shutdown_hook) if shutdown_hook
      begin
        Reactor.register_reactor(self)
        @running = true
        if callback = (callback || block)
          add_timer(0) { callback.call(self) }
        end
        @selector = Selector.open
        @connection_manager = ConnectionManager.new(@selector)
        @run_reactor = true
        run_reactor while @run_reactor
      ensure
        ZMachine.logger.debug("zmachine:reactor:#{__method__}", stop: :selector) if ZMachine.debug
        @selector.close rescue nil
        @selector = nil
        ZMachine.logger.debug("zmachine:reactor:#{__method__}", stop: :connections) if ZMachine.debug
        @connection_manager.shutdown
        ZMachine.logger.debug("zmachine:reactor:#{__method__}", stop: :shutdown_hooks) if ZMachine.debug
        @shutdown_hooks.pop.call until @shutdown_hooks.empty?
        @next_tick_queue = ConcurrentLinkedQueue.new
        @running = false
        Reactor.unregister_reactor(self)
        ZMachine.logger.debug("zmachine:reactor:#{__method__}", stop: :zcontext) if ZMachine.debug
        ZMachine.reactor = nil
      end
    end

    def run_reactor
      ZMachine.logger.debug("zmachine:reactor:#{__method__}") if ZMachine.debug
      run_deferred_callbacks
      return unless @run_reactor
      @wheel.advance
      return unless @run_reactor
      @connection_manager.cleanup
      if @connection_manager.idle?
        ZMachine.logger.debug("zmachine:reactor:#{__method__}", select: @heartbeat_interval) if ZMachine.debug
        @selector.select(@heartbeat_interval * 1000)
      else
        ZMachine.logger.debug("zmachine:reactor:#{__method__}", select: :now) if ZMachine.debug
        @selector.select_now
      end
      @connection_manager.process
    end

    def running?
      @running
    end

    def stop_event_loop
      @run_reactor = false
      @connection_manager.shutdown
      wakeup
    end

    def stop_server(channel)
      channel.close
    end

    private

    def check_reactor_thread
      raise NoReactorError if !Thread.current[:reactor]
      raise NotReactorOwner if Thread.current[:reactor] != self
    end

    def run_deferred_callbacks
      ZMachine.logger.debug("zmachine:reactor:#{__method__}") if ZMachine.debug
      while callback = @next_tick_queue.poll
        callback.call
      end
    end

    def wakeup
      ZMachine.logger.debug("zmachine:reactor:#{__method__}") if ZMachine.debug
      @selector.wakeup if @selector
    end

  end
end
