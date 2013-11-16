java_import java.io.IOException
java_import java.nio.ByteBuffer
java_import java.nio.channels.SelectionKey

module ZMachine
  class Connection

    extend Forwardable

    attr_accessor :channel

    def self.new(*args, &block)
      allocate.instance_eval do
        initialize(*args, &block)
        post_init
        self
      end
    end

    # channel type dispatch

    def bind(address, port_or_type)
      ZMachine.logger.debug("zmachine:connection:#{__method__}", connection: self) if ZMachine.debug
      if address =~ %r{\w+://}
        @channel = ZMQChannel.new(port_or_type)
        @channel.bind(address)
      else
        @channel = TCPChannel.new
        @channel.bind(address, port_or_type)
      end
      self
    end

    def connect(address, port_or_type)
      ZMachine.logger.debug("zmachine:connection:#{__method__}", connection: self) if ZMachine.debug
      if address.nil? or address =~ %r{\w+://}
        @channel = ZMQChannel.new(port_or_type)
        @channel.connect(address) if address
      else
        @channel = TCPChannel.new
        @channel.connect(address, port_or_type)
      end
      if @connect_timeout
        @timer = ZMachine.add_timer(@connect_timeout) do
          ZMachine.reactor.close_connection(self)
        end
      end
      self
    end

    def_delegator :@channel, :bound?
    def_delegator :@channel, :closed?
    def_delegator :@channel, :connected?
    def_delegator :@channel, :connection_pending?

    # EventMachine Connection API

    def _not_implemented
      raise RuntimeError.new("API call not implemented! #{caller[0]}")
    end

    def close_connection(after_writing = false)
      @channel.close(after_writing)
    end

    alias :close :close_connection

    def close_connection_after_writing
      close_connection(true)
    end

    alias :close_after_writing close_connection_after_writing

    def comm_inactivity_timeout
      @inactivity_timeout
    end

    def comm_inactivity_timeout=(value)
      @inactivity_timeout = value
    end

    alias :set_comm_inactivity_timeout :comm_inactivity_timeout=

    def connection_accepted(channel)
    end

    def connection_completed
    end

    def detach
      _not_implemented
    end

    def error?
      _not_implemented
    end

    def get_idle_time
      (System.nano_time - @last_activity) / 1_000_000
    end

    def get_peer_cert
      _not_implemented
    end

    def get_peername
      if peer = @channel.peer
        ::Socket.pack_sockaddr_in(*peer)
      end
    end

    def get_pid
      _not_implemented
    end

    def get_proxied_bytes
      _not_implemented
    end

    def get_sock_opt(level, option)
      _not_implemented
    end

    def get_sockname
      _not_implemented
    end

    def get_status
      _not_implemented
    end

    def notify_readable=(mode)
      _not_implemented
    end

    def notify_readable?
      true
    end

    def notify_writable=(mode)
      _not_implemented
    end

    def notify_writable?
      @channel.can_send?
    end

    def pause
      _not_implemented
    end

    def paused?
      _not_implemented
    end

    def pending_connect_timeout=(value)
      @connect_timeout = value
    end

    alias :set_pending_connect_timeout :pending_connect_timeout=

    def post_init
    end

    def proxy_completed
      _not_implemented
    end

    def proxy_incoming_to(conn, bufsize = 0)
      _not_implemented
    end

    def proxy_target_unbound
      _not_implemented
    end

    def receive_data(data)
    end

    def reconnect(server, port_or_type)
      ZMachine.reconnect(server, port_or_type, self)
    end

    def resume
      _not_implemented
    end

    def send_data(data)
      ZMachine.logger.debug("zmachine:connection:#{__method__}", connection: self) if ZMachine.debug
      @channel.send_data(data)
      update_events
    end

    def send_datagram(data, recipient_address, recipient_port)
      _not_implemented
    end

    def send_file_data(filename)
      _not_implemented
    end

    def set_sock_opt(level, optname, optval)
      _not_implemented
    end

    def ssl_handshake_completed
      _not_implemented
    end

    def ssl_verify_peer(cert)
      _not_implemented
    end

    def start_tls(args = {})
      _not_implemented
    end

    def stop_proxying
      _not_implemented
    end

    def stream_file_data(filename, args = {})
      _not_implemented
    end

    def unbind
    end

    # triggers

    def acceptable!
      client = @channel.accept
      connection_accepted(client) if client.connected?
      ZMachine.logger.debug("zmachine:connection:#{__method__}", connection: self, client: client) if ZMachine.debug
      self.class.new.tap do |connection|
        connection.channel = client
      end
    end

    def connectable!
      ZMachine.logger.debug("zmachine:connection:#{__method__}", connection: self) if ZMachine.debug
      @channel.finish_connecting
      @timer.cancel if @timer # cancel pending connect timer
      mark_active!
      connection_completed if @channel.connected?
      update_events
      nil
    end

    def readable!
      ZMachine.logger.debug("zmachine:connection:#{__method__}", connection: self) if ZMachine.debug
      mark_active!
      data = @channel.read_inbound_data
      receive_data(data) if data
      nil
    end

    def writable!
      ZMachine.logger.debug("zmachine:connection:#{__method__}", connection: self) if ZMachine.debug
      mark_active!
      @channel.write_outbound_data
      update_events
      nil
    end

    # selector registration

    def register(selector)
      ZMachine.logger.debug("zmachine:connection:#{__method__}", connection: self, fd: @channel.selectable_fd) if ZMachine.debug
      @channel_key ||= @channel.selectable_fd.register(selector, current_events, self)
    end

    def update_events
      return unless @channel_key
      ZMachine.logger.debug("zmachine:connection:#{__method__}", connection: self) if ZMachine.debug
      @channel_key.interest_ops(current_events)
    end

    def current_events
      if @channel.is_a?(ZMQChannel)
        return SelectionKey::OP_READ
      end

      if bound?
        return SelectionKey::OP_ACCEPT
      end

      if connection_pending?
        return SelectionKey::OP_CONNECT
      end

      events = 0

      events |= SelectionKey::OP_READ if notify_readable?
      events |= SelectionKey::OP_WRITE if notify_writable?

      return events
    end

    def process_events
      return unless @channel_key
      ZMachine.logger.debug("zmachine:connection:#{__method__}", connection: self) if ZMachine.debug
      if @channel_key.connectable?
        connectable!
      elsif @channel_key.acceptable?
        acceptable!
      else
        writable! if @channel_key.writable?
        readable! if @channel_key.readable?
      end
    end

    def mark_active!
      @last_activity = System.nano_time
      renew_timer if @inactivity_timeout
    end

    def renew_timer
      @timer.cancel if @timer
      @timer = ZMachine.add_timer(@inactivity_timeout) do
        ZMachine.reactor.close_connection(self)
      end
    end

  end
end
