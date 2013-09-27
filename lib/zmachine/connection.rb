module ZMachine
  class Connection

    attr_accessor :channel

    extend Forwardable

    alias original_method method

    def self.new(channel, *args, &block)
      allocate.instance_eval do
        @channel = channel
        initialize(*args, &block)
        post_init
        self
      end
    end

    def initialize(*args, &block)
    end

    # callbacks

    def post_init
    end

    def connection_completed
    end

    def receive_data(data)
    end

    def send3(a,b,c)
      @channel.send3 a,b,c
    end
    def send2(a,b)
      @channel.send2 a,b
    end

    def unbind
    end

    def reconnect(server, port)
      ZMachine.reconnect server, port, self
    end

    # public API

    def_delegator :@channel, :close_connection

    def close_connection_after_writing
      close_connection(true)
    end

    def comm_inactivity_timeout
    end

    def comm_inactivity_timeout=(value)
    end

    alias :set_comm_inactivity_timeout :comm_inactivity_timeout=

    def detach
      _not_implemented
    end

    def error?
      errno = ZMachine::report_connection_error_status(@signature)
      case errno
      when 0
        false
      when -1
        true
      else
        Errno::constants.select do |name|
          Errno.__send__(:const_get, name)::Errno == errno
        end.first
      end
    end

    def get_idle_time
      _not_implemented
    end

    def get_peer_cert
      _not_implemented
    end

    def get_peername
      if peer = @channel.peer_name
        ::Socket.pack_sockaddr_in(*peer)
      end
    end

    def get_pid
      _not_implemented
    end

    def get_proxied_bytes
      _not_implemented
    end

    def_delegator :@channel, :get_sock_opt

    def get_sockname
      if sock_name = @channel.sock_name
        ::Socket.pack_sockaddr_in(*sock_name)
      end
    end

    def get_status
    end

    def notify_readable=(mode)
      _not_implemented
    end

    def notify_readable?
      _not_implemented
    end

    def notify_writable=(mode)
      _not_implemented
    end

    def notify_writable?
      _not_implemented
    end

    def pause
      _not_implemented
    end

    def paused?
      _not_implemented
    end

    def pending_connect_timeout=(value)
    end

    alias :set_pending_connect_timeout :pending_connect_timeout=

    def proxy_completed
      _not_implemented
    end

    def proxy_incoming_to(conn, bufsize = 0)
      _not_implemented
    end

    def proxy_target_unbound
      _not_implemented
    end

    def resume
      _not_implemented
    end

    def_delegator :@channel, :send_data

    def send_datagram(data, recipient_address, recipient_port)
      _not_implemented
    end

    def send_file_data(filename)
      _not_implemented
    end

    def_delegator :@channel, :set_sock_opt

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

    private

    def _not_implemented
      raise RuntimeError.new("API call not implemented!")
    end
  end
end
