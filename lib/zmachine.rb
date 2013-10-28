require 'zmachine/jeromq-0.3.0-SNAPSHOT.jar'
java_import org.zeromq.ZContext

require 'madvertise/boot'

require 'zmachine/connection'
require 'zmachine/deferrable'
require 'zmachine/reactor'
require 'zmachine/timers'

module ZMachine
  class ConnectionError < RuntimeError; end
  class ConnectionNotBound < RuntimeError; end
  class UnknownTimerFired < RuntimeError; end
  class Unsupported < RuntimeError; end

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

  # TODO: move to ZMQChannel
  def self.context
    Thread.current[:context] ||= ZContext.new
  end

  def self._not_implemented
    raise RuntimeError.new("API call not implemented! #{caller[0]}")
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

  def self.attach(io, handler = nil, *args, &blk)
    _not_implemented
  end

  def self.bind_connect(bind_addr, bind_port, server, port = nil, handler = nil, *args)
    _not_implemented
  end

  def self.Callback(object = nil, method = nil, &blk)
    _not_implemented
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

  def self.connect_unix_domain(socketname, *args, &blk)
    _not_implemented
  end

  def self.connection_count
    reactor.connections.size
  end

  def self.defer(op = nil, callback = nil, &blk)
    _not_implemented
  end

  def self.defers_finished?
    _not_implemented
  end

  def self.disable_proxy(from)
    _not_implemented
  end

  def self.enable_proxy(from, to, bufsize = 0, length = 0)
    _not_implemented
  end

  def self.error_handler(callback = nil, &block)
    _not_implemented
  end

  def self.fork_reactor(&block)
    _not_implemented
  end

  def self.get_max_timers
    _not_implemented
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

  def self.open_datagram_socket(address, port, handler = nil, *args)
    _not_implemented
  end

  def self.popen(cmd, handler = nil, *args)
    _not_implemented
  end

  def self.reactor_running?
    reactor.running?
  end

  def self.reactor_thread?
    _not_implemented
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

  def self.schedule(*a, &b)
    _not_implemented
  end

  def self.set_descriptor_table_size(n_descriptors = nil)
    _not_implemented
  end

  def self.set_effective_user(username)
    _not_implemented
  end

  def self.set_max_timers(ct)
    _not_implemented
  end

  def self.set_quantum(mills)
    _not_implemented
  end

  def self.spawn(&block)
    _not_implemented
  end

  def self.start_server(server, port_or_type=nil, handler=nil, *args, &block)
    reactor.bind(server, port_or_type, handler, *args, &block)
  end

  def self.start_unix_domain_server(filename, *args, &block)
    _not_implemented
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

  def self.system(cmd, *args, &cb)
    _not_implemented
  end

  def self.tick_loop(*a, &b)
    _not_implemented
  end

  def self.watch(io, handler = nil, *args, &blk)
    _not_implemented
  end

  def self.watch_file(filename, handler = nil, *args)
    _not_implemented
  end

  def self.watch_process(pid, handler = nil, *args)
    _not_implemented
  end

end

if ENV['DEBUG']
  $log.level = :debug
  ZMachine.logger = $log
  ZMachine.debug = true
end
