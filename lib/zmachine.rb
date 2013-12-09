require 'zmachine/jeromq-0.3.2-SNAPSHOT.jar'
java_import org.zeromq.ZContext

require 'liquid/boot'

require 'zmachine/connection'
require 'zmachine/deferrable'
require 'zmachine/reactor'
require 'zmachine/timers'

module ZMachine
  class ConnectionError < RuntimeError; end

  class << self
    attr_accessor :logger
    attr_accessor :debug
  end

  def self.clear_current_reactor
    Thread.current[:reactor] = nil
  end

  def self.reactor
    Thread.current[:reactor] ||= Reactor.new
  end

  def self.context
    Thread.current[:context] ||= ZContext.new
  end

  def self.add_periodic_timer(*args, &block)
    interval = args.shift
    callback = args.shift || block
    PeriodicTimer.new(interval, callback)
  end

  def self.add_shutdown_hook(&block)
    reactor.add_shutdown_hook(&block)
  end

  def self.add_timer(*args, &block)
    reactor.add_timer(*args, &block)
  end

  def self.cancel_timer(timer_or_sig)
    timer_or_sig.cancel # we do not support signatures
  end

  def self.close_connection(connection)
    reactor.close_connection(connection)
  end

  def self.connect(server, port_or_type=nil, handler=nil, *args, &block)
    reactor.connect(server, port_or_type, handler, *args, &block)
  end

  def self.connection_count
    reactor.connections.size
  end

  def self.heartbeat_interval
    reactor.heartbeat_interval
  end

  def self.heartbeat_interval=(time)
    reactor.heartbeat_interval = time
  end

  def self.next_tick(callback=nil, &block)
    reactor.next_tick(callback, &block)
  end

  def self.reactor_running?
    reactor.running?
  end

  def self.reconnect(server, port, handler)
    reactor.reconnect(server, port, handler)
  end

  def self.run(callback=nil, shutdown_hook=nil, &block)
    reactor.run(callback, shutdown_hook, &block)
  end

  def self.run_block(&block)
    pr = proc {
      block.call
      ZMachine::stop_event_loop
    }
    run(&pr)
  end

  def self.start_server(server, port_or_type=nil, handler=nil, *args, &block)
    reactor.bind(server, port_or_type, handler, *args, &block)
  end

  def self.stop_event_loop
    reactor.stop_event_loop
  end

  def self.stop_server(signature)
    reactor.stop_server(signature)
  end

  def self.stop
    Reactor.terminate_all_reactors
  end

end

if ENV['DEBUG']
  $log.level = :debug
  ZMachine.logger = $log
  ZMachine.debug = true
end
