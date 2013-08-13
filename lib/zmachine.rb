require 'socket'
require 'zmachine/reactor'
require 'zmachine/connection'

java_import java.io.FileDescriptor
java_import java.nio.channels.SocketChannel

module ZMachine
  class ConnectionError < RuntimeError; end
  class ConnectionNotBound < RuntimeError; end
  class UnknownTimerFired < RuntimeError; end
  class Unsupported < RuntimeError; end

  @next_tick_mutex = Mutex.new
  @reactor_running = false
  @next_tick_queue = []
  @shutdown_hooks = []

  ERRNOS = Errno::constants.grep(/^E/).inject(Hash.new(:unknown)) { |hash, name|
    errno = Errno.__send__(:const_get, name)
    hash[errno::Errno] = errno
    hash
  }

  def self.run(callback=nil, shutdown_hook=nil, &block)
    callback = callback || block

    @shutdown_hooks.unshift(shutdown_hook) if shutdown_hook

    if reactor_running?
      callback.call if callback # next_tick(callback)
    else
      @connections = {}
      @acceptors = {}
      @timers = {}
      @wrapped_exception = nil
      @next_tick_queue ||= []
      @shutdown_hooks ||= []
      begin
        @reactor_running = true
        @reactor = Reactor.new
        add_timer(0, callback) if callback
        if @next_tick_queue && !@next_tick_queue.empty?
          add_timer(0) { signal_loopbreak }
        end
        @reactor.run
      ensure
        until @shutdown_hooks.empty?
          @shutdown_hooks.pop.call
        end

        begin
          @reactor = nil
        ensure
          @next_tick_queue = []
        end
        @reactor_running = false
      end

      raise @wrapped_exception if @wrapped_exception
    end
  end

  def self.run_block(&block)
    pr = proc {
      block.call
      ZMachine::stop
    }
    run(&pr)
  end

  def self.add_shutdown_hook(&block)
    @shutdown_hooks << block
  end

  def self.add_timer(*args, &block)
    interval = args.shift
    callback = args.shift || block
    if callback
      signature = @reactor.install_oneshot_timer((interval.to_f * 1000).to_i)
      @timers[signature] = callback
      signature
    end
  end

  def self.add_periodic_timer(*args, &block)
    interval = args.shift
    callback = args.shift || block
    ZMachine::PeriodicTimer.new(interval, callback)
  end

  def self.cancel_timer(timer_or_sig)
    if timer_or_sig.respond_to? :cancel
      timer_or_sig.cancel
    else
      @timers[timer_or_sig] = false if @timers.has_key?(timer_or_sig)
    end
  end

  def self.stop_event_loop
    ZMachine::stop
  end

  def self.start_server(server, port=nil, handler=nil, *args, &block)
    begin
      port = Integer(port)
    rescue ArgumentError, TypeError
      args.unshift(handler) if handler
      handler = port
      port = nil
    end if port

    klass = _klass_from_handler(Connection, handler, *args)

    signature = @reactor.start_tcp_server(server, port)
    @acceptors[signature] = [klass, args, block]
    signature
  end

  def self.stop_server(signature)
    @reactor.stop_tcp_server(signature)
  end

  def self.connect(server, port=nil, handler=nil, *args, &block)
    begin
      port = Integer(port)
    rescue ArgumentError, TypeError
      args.unshift handler if handler
      handler = port
      port = nil
    end if port

    klass = _klass_from_handler(Connection, handler, *args)

    signature = @reactor.connect_tcp_server(server, port)
    connection = klass.new signature, *args
    @connections[signature] = connection
    block_given? and yield connection
    connection
  end

  def self.watch(io, handler=nil, *args, &block)
    attach_io(io, true, handler, *args, &block)
  end

  def self.attach(io, handler=nil, *args, &block)
    attach_io io, false, handler, *args, &block
  end

  def self.attach_io(io, watch_mode, handler=nil, *args)
    klass = _klass_from_handler(Connection, handler, *args)

    notifiers = klass.public_instance_methods.any? do |m|
      [:notify_readable, :notify_writable].include?(m.to_sym)
    end
    if !watch_mode and notifiers
      raise ArgumentError, "notify_readable/writable with ZMachine.attach is not supported. Use ZMachine.watch(io){ |connection| connection.notify_readable = true }"
    end

    if io.respond_to?(:fileno)
      fd = JRuby.runtime.getDescriptorByFileno(io.fileno).getChannel
    else
      fd = io
    end

    signature = _attach_fd(fd, watch_mode)
    connection = klass.new(signature, *args)

    connection.instance_variable_set(:@io, io)
    connection.instance_variable_set(:@watch_mode, watch_mode)
    connection.instance_variable_set(:@fd, fd)

    @connections[signature] = connection
    yield connection if block_given?
    connection
  end

  def self.reconnect server, port, handler
    raise "invalid handler" unless handler.respond_to?(:connection_completed)
    return handler if @connections.has_key?(handler.signature)

    signature = @reactor.connect_tcp_server(server, port)
    handler.signature = signature
    @connections[signature] = handler
    block_given? and yield handler
    handler
  end

  def self.set_quantum mills
  end

  def self.set_max_timers ct
    set_max_timer_count ct
  end

  def self.get_max_timers
    get_max_timer_count
  end

  def self.connection_count
    @reactor.get_connection_count
  end

  def self.run_deferred_callbacks
    size = @next_tick_mutex.synchronize { @next_tick_queue.size }
    size.times do |i|
      callback = @next_tick_mutex.synchronize { @next_tick_queue.shift }
      begin
        callback.call
      ensure
        ZMachine.next_tick {} if $!
      end
    end
  end

  def self.next_tick pr=nil, &block
    raise ArgumentError, "no proc or block given" unless ((pr && pr.respond_to?(:call)) or block)
    @next_tick_mutex.synchronize do
      @next_tick_queue << ( pr || block )
    end
    signal_loopbreak if reactor_running?
  end

  def self.set_descriptor_table_size n_descriptors=nil
    ZMachine::set_rlimit_nofile n_descriptors
  end

  def self.reactor_running?
    @reactor_running || false
  end


  def self.error_handler cb = nil, &block
    if cb or block
      @error_handler = cb || block
    elsif instance_variable_defined? :@error_handler
      remove_instance_variable :@error_handler
    end
  end

  def self.heartbeat_interval
  end

  def self.heartbeat_interval=(time)
  end

  private

  def self.stop
    @reactor.stop
  end

  def self._klass_from_handler(klass = Connection, handler = nil, *args)
    klass = if handler and handler.is_a?(Class)
      raise ArgumentError, "must provide module or subclass of #{klass.name}" unless klass >= handler
      handler
    elsif handler
      begin
        handler::EM_CONNECTION_CLASS
      rescue NameError
        handler::const_set(:EM_CONNECTION_CLASS, Class.new(klass) {include handler})
      end
    else
      klass
    end

    arity = klass.instance_method(:initialize).arity
    expected = arity >= 0 ? arity : -(arity + 1)
    if (arity >= 0 and args.size != expected) or (arity < 0 and args.size < expected)
      raise ArgumentError, "wrong number of arguments for #{klass}#initialize (#{args.size} for #{expected})"
    end

    klass
  end

  def self._send_data sig, data, length
    @reactor.send_data sig, data.to_java_bytes
  end

  def self._close_connection sig, after_writing
    @reactor.close_connection sig, after_writing
  end

  def self._get_peername sig
    if peer = @reactor.peer_name(sig)
      Socket.pack_sockaddr_in(*peer)
    end
  end

  def self._get_sockname sig
    if sock_name = @reactor.get_sock_name(sig)
      Socket.pack_sockaddr_in(*sockName)
    end
  end

  def self._attach_fd(fileno, watch_mode)
    if fileno.java_kind_of?(java.nio.channels.Channel)
      field = fileno.getClass.getDeclaredField('fdVal')
      field.setAccessible(true)
      fileno = field.get(fileno)
    elsif fileno.is_a?(Fixnum)
      raise "can't open STDIN as selectable in Java =(" if fileno == 0
    else
      raise ArgumentError, 'attach_fd requires Java Channel or POSIX fileno'
    end

    if fileno.is_a?(Fixnum)
      fd = FileDescriptor.new
      fd.fd = fileno

      ch = SocketChannel.open
      ch.configure_blocking(false)
      ch.kill
      ch.fd = fd
      ch.fdVal = fileno
      ch.state = ch.ST_CONNECTED
    end

    @reactor.attach_channel(ch, watch_mode)
  end

  def self._detach_fd(sig)
    if ch = @reactor.detach_channel(sig)
      ch.fdVal
    end
  end

  def self._set_notify_readables(sig, mode)
    @reactor.set_notify_readable(sig, mode)
  end

  def self._set_notify_writable(sig, mode)
    @reactor.set_notify_writable(sig, mode)
  end

  def self._is_notify_readable(sig)
    @reactor.is_notify_readable(sig)
  end

  def self._is_notify_writable(sig)
    @reactor.is_notify_writable(sig)
  end

  def self._connection_unbound(signature)
    if connection = @connections.delete(signature)
      begin
        if connection.original_method(:unbind).arity != 0
          connection.unbind(data == 0 ? nil : ZMachine::ERRNOS[data])
        else
          connection.unbind
        end
        if connection.instance_variable_defined?(:@io) and !connection.instance_variable_get(:@watch_mode)
          io = connection.instance_variable_get(:@io)
          begin
            io.close
          rescue Errno::EBADF, IOError
          end
        end
      rescue
        @wrapped_exception = $!
        stop
      end
    elsif connection = @acceptors.delete(signature)
    else
      if $! # Bubble user generated errors.
        @wrapped_exception = $!
        ZMachine.stop
      else
        raise ConnectionNotBound, "received ConnectionUnbound for an unknown signature: #{signature}"
      end
    end
  end

  def self._connection_accepted(signature, data)
    handler, args, block = @acceptors[signature]
    raise NoHandlerForAcceptedConnection unless handler
    connection = handler.new(data, *args)
    @connections[data] = connection
    block and block.call(connection)
  end

  def self._connection_completed(signature)
    connection = @connections[signature] or raise ConnectionNotBound, "received ConnectionCompleted for unknown signature: #{signature}"
    connection.connection_completed
  end

  def self._timer_fired(data)
    timer = @timers.delete(data)
    return if timer == false # timer cancelled
    timer or raise UnknownTimerFired, "timer data: #{data}"
    timer.call
  end

  def self._connection_data(signature, data)
    connection = @connections[signature] or raise ConnectionNotBound, "received data #{data} for unknown signature: #{signature}"
    connection.receive_data(data)
  end

  def self._loopbreak_signaled
    run_deferred_callbacks
  end

  def self._connection_notify_readable(signature)
    connection = @connections[signature] or raise ConnectionNotBound
    connection.notify_readable
  end

  def self._connection_notify_writable(signature)
    connection = @connections[signature] or raise ConnectionNotBound
    connection.notify_writable
  end
end
