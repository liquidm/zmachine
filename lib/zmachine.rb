require 'forwardable'

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

  def self.reactor
    Thread.current[:reactor] ||= Reactor.new
  end

  def self.context
    Thread.current[:context] ||= ZContext.new
  end

  class << self
    extend Forwardable
    def_delegator :reactor, :add_shutdown_hook
    def_delegator :reactor, :add_timer
    def_delegator :reactor, :cancel_timer
    def_delegator :reactor, :connect
    def_delegator :reactor, :connection_count
    def_delegator :reactor, :error_handler
    def_delegator :reactor, :next_tick
    def_delegator :reactor, :run
    def_delegator :reactor, :reactor_running?
    def_delegator :reactor, :reconnect
    def_delegator :reactor, :start_server
    def_delegator :reactor, :stop_event_loop
    def_delegator :reactor, :stop_server
  end

  def self._not_implemented
    raise RuntimeError.new("API call not implemented!")
  end

  def self.add_periodic_timer(*args, &block)
    interval = args.shift
    callback = args.shift || block
    PeriodicTimer.new(interval, callback)
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

  def self.connect_unix_domain(socketname, *args, &blk)
    _not_implemented
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

  def self.fork_reactor(&block)
    _not_implemented
  end

  def self.get_max_timers
    _not_implemented
  end

  def self.heartbeat_interval
    _not_implemented
  end

  def self.heartbeat_interval=(time)
    _not_implemented
  end

  def self.open_datagram_socket(address, port, handler = nil, *args)
    _not_implemented
  end

  def self.popen(cmd, handler = nil, *args)
    _not_implemented
  end

  def self.reactor_thread?
    _not_implemented
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

  def self.start_unix_domain_server(filename, *args, &block)
    _not_implemented
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
