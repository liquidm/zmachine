require 'forwardable'
require 'zmachine/connection'
require 'zmachine/reactor'

java_import java.lang.ThreadLocal

module ZMachine
  class ConnectionError < RuntimeError; end
  class ConnectionNotBound < RuntimeError; end
  class UnknownTimerFired < RuntimeError; end
  class Unsupported < RuntimeError; end

  def self.instance
    @reactor ||= ThreadLocal.new
    @reactor.set(Reactor.new) unless @reactor.get
    @reactor.get
  end

  class << self
    extend Forwardable
    def_delegator :instance, :add_periodic_timer
    def_delegator :instance, :add_shutdown_hook
    def_delegator :instance, :add_timer
    def_delegator :instance, :attach
    def_delegator :instance, :cancel_timer
    def_delegator :instance, :connect
    def_delegator :instance, :connection_count
    def_delegator :instance, :error_handler
    def_delegator :instance, :next_tick
    def_delegator :instance, :run
    def_delegator :instance, :runnning?, :reactor_running?
    def_delegator :instance, :reconnect
    def_delegator :instance, :stop, :stop_event_loop
    def_delegator :instance, :stop_server
    def_delegator :instance, :watch
  end

  def self._not_implemented
    raise RuntimeError.new("API call not implemented!")
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

  def self.start_server(server, port_or_type=nil, handler=nil, *args, &block)
    if server =~ %r{\w+://}
      instance.start_zmq_server(server, port_or_type, handler, *args)
    else
      instance.start_tcp_server(server, port_or_type, handler, *args, &block)
    end
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

  def self.watch_file(filename, handler = nil, *args)
    _not_implemented
  end

  def self.watch_process(pid, handler = nil, *args)
    _not_implemented
  end

end
