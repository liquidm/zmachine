java_import java.io.IOException
java_import java.net.InetSocketAddress
java_import java.nio.ByteBuffer
java_import java.nio.channels.ClosedChannelException
java_import java.nio.channels.SelectionKey
java_import java.nio.channels.Selector
java_import java.nio.channels.ServerSocketChannel
java_import java.util.TreeMap
java_import java.util.concurrent.atomic.AtomicBoolean

require 'zmachine/channel'

module ZMachine
  class Reactor

    def initialize
      @timers = TreeMap.new
      @connections = {}
      @acceptors = {}
      @new_connections = []
      @unbound_connections = []
      @detached_connections = []
      @next_signature = 0

      @loop_breaker = AtomicBoolean.new
      @loop_breaker.set(false)

      # don't use a direct buffer. Ruby doesn't seem to like them.
      @read_buffer = ByteBuffer.allocate(32*1024)
    end

    def run
      @selector = Selector.open
      @run_reactor = true

      while @run_reactor
        run_loopbreaks
        break unless @run_reactor
        run_timers
        break unless @run_reactor
        remove_unbound_connections
        check_io
        add_new_connections
        process_io
      end

      close
    end

    def add_new_connections
      @detached_connections.each(&:cleanup)
      @detached_connections.clear

      @new_connections.each do |signature|
        channel = @connections[signature]
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
        channel = @connections.delete(signature)
        next unless channel
        ZMachine::_connection_unbound(signature)
        channel.close
        if channel and channel.attached
          @detached_connections << channel
        end
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
          server = @acceptors.remove(selected_key.attachment)
          if server
            server.close rescue nil
          end
          break
        end

        begin
          socket_channel.configure_blocking(false)
        rescue IOException => e
          e.printStackTrace
          next
        end

        signature = next_signature
        channel = Channel.new(socket_channel, signature, @selector)
        @connections[signature] = channel
        @new_connections << signature

        ZMachine::_connection_accepted(selected_key.attachment, signature)
      end
    end

    def is_readable(selected_key)
      channel = selected_key.attachment
      signature = channel.signature

      if channel.watch_only
        if channel.notify_readable
          ZMachine::_connection_notify_readable(signature)
        end
      else
        @read_buffer.clear

        begin
          channel.read_inbound_data(@read_buffer)
          @read_buffer.flip
          if @read_buffer.limit > 0
            buffer = String.from_java_bytes(@read_buffer.array[@read_buffer.position...@read_buffer.limit])
            ZMachine::_connection_data(signature, buffer)
          end
        rescue IOException => e
          @unbound_connections << signature
        end
      end
    end

    def is_writable(selected_key)
      channel = selected_key.attachment
      signature = channel.signature

      if channel.watch_only
        if channel.notify_writable
          ZMachine::_connection_notify_writable(signature)
        end
      else
        begin
          @unbound_connections << signature unless channel.write_outbound_data
        rescue IOException => e
          @unbound_connections << signature
        end
      end
    end

    def is_connectable(selected_key)
      channel = selected_key.attachment
      signature = channel.signature

      begin
        if channel.finish_connecting
          ZMachine::_connection_completed(signature)
        else
          @unbound_connections << signature
        end
      rescue IOException => e
        @unbound_connections << signature
      end
    end

    def close
      @selector.close rescue nil
      @selector = nil
      @acceptors.values.each(&:close)

      connections = @connections.values.compact
      @connections.clear

      connections.each do |connection|
        ZMachine::_connection_unbound(connection.signature)
        connection.close
        if connection and connection.attached?
          @detached_connections << connection
        end
      end

      @detached_connections.each do |connection|
        connection.cleanup
      end
      @detached_connections.clear
    end

    def run_loopbreaks
      return unless @loop_breaker.get_and_set(false)
      ZMachine::_loopbreak_signaled
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

        callbacks = @timers.get(timer_key)
        @timers.remove(timer_key)

        # Fire all timers at this timestamp
        callbacks.each do |signature|
          ZMachine::_timer_fired(signature)
        end
      end
    end

    def install_oneshot_timer(milliseconds)
      signature = next_signature
      deadline = java.util.Date.new.time + milliseconds

      if @timers.contains_key(deadline)
        @timers.get(deadline).add(signature)
      else
        callbacks = [signature]
        @timers.put(deadline, callbacks)
      end

      return signature
    end

    def start_tcp_server(address, port)
      address = InetSocketAddress.new(address, port)
      server_socket_channel = ServerSocketChannel.open
      server_socket_channel.configure_blocking(false)
      server_socket_channel.socket.bind(address)
      signature = next_signature
      @acceptors[signature] = server_socket_channel
      server_socket_channel.register(@selector, SelectionKey::OP_ACCEPT, signature)
      return signature
    end

    def stop_tcp_server(signature)
      server_socket_channel = @acceptors.remove(signature)
      server_socket_channel.close
    end

    def send_data(signature, buffer)
      @connections[signature].schedule_outbound_data(ByteBuffer.wrap(buffer))
    end

    def connect_tcp_server(address, port)
      signature = next_signature

      begin
        socket_channel = SocketChannel.open
        socket_channel.configure_blocking(false)

        channel = Channel.new(socket_channel, signature, @selector)
        address = InetSocketAddress.new(address, port)

        if socket_channel.connect(address)
          # Connection returned immediately. Can happen with localhost connections.
          # WARNING, this code is untested due to lack of available test conditions.
          # Ought to be be able to come here from a localhost connection, but that
          # doesn't happen on Linux. (Maybe on FreeBSD?)
          # The reason for not handling this until we can test it is that we
          # really need to return from this function WITHOUT triggering any EM events.
          # That's because until the user code has seen the signature we generated here,
          # it won't be able to properly dispatch them. The C++ EM deals with this
          # by setting pending mode as a flag in ALL eventable descriptors and making
          # the descriptor select for writable. Then, it can send UNBOUND and
          # CONNECTION_COMPLETED on the next pass through the loop, because writable will
          # fire.
          raise RuntimeError.new("immediate-connect unimplemented")
        else
          channel.connect_pending = true
          @connections[signature] = channel
          @new_connections << signature
        end
      rescue IOException => e
        # Can theoretically come here if a connect failure can be determined immediately.
        # I don't know how to make that happen for testing purposes.
        raise RuntimeError.new("immediate-connect unimplemented: " + e.toString())
      end
      return signature
    end

    def close_connection(signature, after_writing)
      channel = @connections[signature]
      if channel and channel.schedule_close(after_writing)
        @unbound_connections << signature
      end
    end

    def signal_loopbreak
      @loop_breaker.set(true)
      @selector.wakeup if @selector
    end

    def get_peer_name(signature)
      @connections[signature].peer_name
    end

    def get_sock_name(signature)
      @connections[signature].sock_name
    end

    def attach_channel(socket_channel, watch_only)
      signature = next_signature

      channel = Channel.new(socket_channel, signature, @selector)
      channel.attached = true
      channel.watch_only = watch_only

      @connections[signature] = channel
      @new_connections << signature

      return signature
    end

    def detach_channel(signature)
      channel = @connections[signature]
      if channel
        @unbound_connections << signature
        return channel.channel
      else
        return nil
      end
    end

    def set_notify_readable(signature, mode)
      @connections[signature].notify_readable = mode
    end

    def set_notify_writable(signature, mode)
      @connections[signature].notify_writable = mode
    end

    def is_notify_readable(signature)
      @connections[signature].notify_readable
    end

    def is_notify_writable(signature)
      @connections[signature].notify_writable
    end

    def get_connection_count
      @connections.size + @acceptors.size
    end

    def next_signature
      @next_signature += 1
    end

  end
end
