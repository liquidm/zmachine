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

require 'zmachine/jeromq-0.3.0-20130721.175323-20.jar'
java_import org.zeromq.ZContext

require 'zmachine/acceptor'
require 'zmachine/tcp_channel'
require 'zmachine/zmq_channel'

module ZMachine
  class Reactor

    def initialize
      @timers = TreeMap.new
      @timer_callbacks = {}
      @connections = {}
      @acceptors = {}
      @new_connections = []
      @unbound_connections = []
      @next_signature = 0
      @shutdown_hooks = []
      @wrapped_exception = nil
      @next_tick_queue = ConcurrentLinkedQueue.new
      @running = false

      # don't use a direct buffer. Ruby doesn't seem to like them.
      @read_buffer = ByteBuffer.allocate(32*1024)

      @context = ZContext.new
    end

    def run(callback=nil, shutdown_hook=nil, &block)
      @callback = callback || block

      add_shutdown_hook(shutdown_hook) if shutdown_hook

      begin
        @running = true

        add_timer(0, @callback) if @callback

        @selector = Selector.open
        @run_reactor = true

        while @run_reactor
          run_deferred_callbacks
          break unless @run_reactor
          run_timers
          break unless @run_reactor
          remove_unbound_connections
          check_io
          add_new_connections
          process_io
        end

        close
      ensure
        @shutdown_hooks.pop.call until @shutdown_hooks.empty?
        @reactor = nil
        @next_tick_queue = ConcurrentLinkedQueue.new
        @running = false
      end

      raise @wrapped_exception if @wrapped_exception
    end

    def error_handler(callback = nil, &block)
      @error_handler = callback || block
    end

    def add_shutdown_hook(&block)
      @shutdown_hooks << block
    end

    def add_timer(*args, &block)
      interval = args.shift
      callback = args.shift || block
      return unless callback

      signature = next_signature
      deadline = java.util.Date.new.time + (interval.to_f * 1000).to_i

      if @timers.contains_key(deadline)
        @timers.get(deadline).add(signature)
      else
        @timers.put(deadline, [signature])
      end

      @timer_callbacks[signature] = callback
      signature
    end

    def cancel_timer(timer_or_sig)
      if timer_or_sig.respond_to?(:cancel)
        timer_or_sig.cancel
      else
        @timer_callbacks[timer_or_sig] = false if @timer_callbacks.has_key?(timer_or_sig)
      end
    end

    def bind_tcp(address, port, handler, *args, &block)
      klass = _klass_from_handler(Connection, handler, *args)
      signature = next_signature
      address = InetSocketAddress.new(address, port)
      selectable_channel = ServerSocketChannel.open
      selectable_channel.configure_blocking(false)
      selectable_channel.socket.bind(address)
      selectable_channel.register(@selector, SelectionKey::OP_ACCEPT, signature)
      @acceptors[signature] = Acceptor.new(selectable_channel, klass, args, block)
      signature
    end

    def bind_zmq(address, type, handler, *args, &block)
      klass = _klass_from_handler(Connection, handler, *args)
      signature = next_signature
      socket = @context.create_socket(type)
      socket.bind(address)
      channel = ZMQChannel.new(socket, signature, @selector)
      acceptor = Acceptor.new(socket, klass, args, block)
      connection = acceptor.klass.new(signature, channel, self, *acceptor.args)
      @connections[signature] = connection
      @acceptors[signature] = acceptor # for close
      channel.register
      signature
    end

    def stop_server(signature)
      @acceptors.remove(signature).close
    end

    def connect_tcp(server, port, handler=nil, *args, &block)
      klass = _klass_from_handler(Connection, handler, *args)
      _connect_tcp(server, port, nil, klass, *args, &block)
    end

    def connect_zmq(server, type, handler=nil, *args)
      klass = _klass_from_handler(Connection, handler, *args)
      _connect_zmq(server, type, klass, *args)
    end

    def reconnect(server, port, connection, &block)
      return connection if @connections.has_key?(connection.signature)
      _connect_tcp(server, port, connection, &block)
    end

    def send_data(signature, data)
      @connections[signature].channel.send_data(data)
    end

    private

    def add_new_connections
      @new_connections.each do |signature|
        channel = @connections[signature].channel
        next unless channel
        begin
          channel.register
        rescue ClosedChannelException
          @unbound_connections << channel.signature
        end
      end
      @new_connections.clear
    end

    def remove_unbound_connections
      @unbound_connections.each do |signature|
        channel = @connections[signature].channel
        _connection_unbound(channel)
      end
      @unbound_connections.clear
    end

    def check_io
      if @new_connections.size > 0
        timeout = -1
      elsif !@timers.empty?
        now = java.util.Date.new.time
        timer_key = @timers.first_key
        diff = timer_key - now;

        if diff <= 0
          timeout = -1
        else
          timeout = diff
        end
      else
        timeout = 0
      end

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
          is_connectable(selected_key)
        elsif selected_key.acceptable?
          is_acceptable(selected_key)
        else
          is_writable(selected_key) if selected_key.writable?
          is_readable(selected_key) if selected_key.readable?
        end
      end
    end

    def is_acceptable(selected_key)
      server_socket_channel = selected_key.channel

      10.times do
        begin
          socket_channel = server_socket_channel.accept
          break unless socket_channel
        rescue IOException => e
          e.printStackTrace
          selected_key.cancel
          @acceptors.remove(selected_key.attachment).close rescue nil
          break
        end

        begin
          socket_channel.configure_blocking(false)
        rescue IOException => e
          e.printStackTrace
          next
        end

        server_signature = selected_key.attachment
        client_signature = next_signature

        channel = TCPChannel.new(socket_channel, client_signature, @selector)
        acceptor = @acceptors[server_signature]
        raise NoHandlerForAcceptedConnection unless acceptor.klass
        connection = acceptor.klass.new(client_signature, channel, self, *acceptor.args)
        @connections[client_signature] = connection
        @new_connections << client_signature
        acceptor.callback.call(connection) if acceptor.callback
      end
    end

    def is_readable(selected_key)
      channel = selected_key.attachment
      signature = channel.signature

      begin
        data = channel.read_inbound_data(@read_buffer)
        puts "is_readable(): data=#{data.inspect}"
        return unless data
        connection = @connections[signature] or raise ConnectionNotBound, "received data #{data} for unknown signature: #{signature}"
        connection.receive_data(data)
      rescue IOException => e
        @unbound_connections << signature
      end
    end

    def is_writable(selected_key)
      channel = selected_key.attachment
      signature = channel.signature

      begin
        @unbound_connections << signature unless channel.write_outbound_data
      rescue IOException => e
        @unbound_connections << signature
      end
    end

    def is_connectable(selected_key)
      channel = selected_key.attachment
      signature = channel.signature

      begin
        if channel.finish_connecting
          connection = @connections[signature] or raise ConnectionNotBound, "received ConnectionCompleted for unknown signature: #{signature}"
          connection.connection_completed
        else
          @unbound_connections << signature
        end
      rescue IOException
        @unbound_connections << signature
      end
    end

    def close
      @selector.close rescue nil
      @selector = nil
      @acceptors.values.each(&:close)

      channels = @connections.values.compact.map(&:channel)
      channels.each do |channel|
        _connection_unbound(channel)
      end
      @connections.clear
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

    def next_tick(callback=nil, &block)
      @next_tick_queue << (callback || block)
      signal_loopbreak if running?
    end

    def running?
      @running || false
    end

    def stop
      @run_reactor = false
      signal_loopbreak
    end

    def run_timers
      now = java.util.Date.new.time
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

    def _connect_tcp(address, port, connection=nil, klass=nil, *args, &block)
      signature = next_signature

      begin
        socket_channel = SocketChannel.open
        socket_channel.configure_blocking(false)

        channel = TCPChannel.new(socket_channel, signature, @selector)
        address = InetSocketAddress.new(address, port)

        if socket_channel.connect(address)
          # Connection returned immediately. Can happen with localhost
          # connections.
          # WARNING, this code is untested due to lack of available test
          # conditions.  Ought to be be able to come here from a localhost
          # connection, but that doesn't happen on Linux. (Maybe on FreeBSD?)
          # The reason for not handling this until we can test it is that we
          # really need to return from this function WITHOUT triggering any EM
          # events.  That's because until the user code has seen the signature
          # we generated here, it won't be able to properly dispatch them. The
          # C++ EM deals with this by setting pending mode as a flag in ALL
          # eventable descriptors and making the descriptor select for
          # writable. Then, it can send UNBOUND and CONNECTION_COMPLETED on the
          # next pass through the loop, because writable will fire.
          raise RuntimeError.new("immediate-connect unimplemented")
        end

        channel.connect_pending = true
        connection ||= klass.new(signature, channel, self, *args)
        connection.signature = signature
        connection.channel = channel
        @connections[signature] = connection
        @new_connections << signature
      rescue IOException => e
        # Can theoretically come here if a connect failure can be determined
        # immediately.  I don't know how to make that happen for testing
        # purposes.
        raise RuntimeError.new("immediate-connect unimplemented: " + e.toString())
      end
      yield connection if block_given?
      return connection
    end

    def _connect_zmq(address, type, klass=nil, *args, &block)
      signature = next_signature
      socket = @context.create_socket(type)
      socket.connect(address)
      channel = ZMQChannel.new(socket, signature, @selector)
      #channel.connect_pending = true
      connection = klass.new(signature, channel, self, *args)
      @connections[signature] = connection
      @new_connections << signature
      yield connection if block_given?
      connection.connection_completed
      return connection
    end

    def close_connection(signature, after_writing)
      channel = @connections[signature].channel
      if channel and channel.schedule_close(after_writing)
        @unbound_connections << signature
      end
    end

    def signal_loopbreak
      @selector.wakeup if @selector
    end

    def connection_count
      @connections.size + @acceptors.size
    end

    def next_signature
      @next_signature += 1
    end

    def _klass_from_handler(klass = Connection, handler = nil, *args)
      if handler and handler.is_a?(Class)
        handler
      elsif handler
        _handler_from_klass(klass, handler)
      else
        klass
      end
    end

    def _handler_from_module(klass, handler)
      handler::EM_CONNECTION_CLASS
    rescue NameError
      handler::const_set(:EM_CONNECTION_CLASS, Class.new(klass) {include handler})
    end

    def _connection_unbound(channel)
      signature = channel.signature
      if connection = @connections.delete(signature)
        begin
          if connection.original_method(:unbind).arity != 0
            connection.unbind(nil)
          else
            connection.unbind
          end
        rescue
          @wrapped_exception = $!
          stop
        end
      elsif @acceptors.delete(signature)
      else
        if $! # Bubble user generated errors.
          @wrapped_exception = $!
          ZMachine.stop
        else
          raise ConnectionNotBound, "received ConnectionUnbound for an unknown signature: #{signature}"
        end
      end
      channel.close
    end

  end
end
