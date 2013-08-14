module ZMachine
  class FileNotFoundException < Exception
  end

  class Connection
    attr_accessor :signature
    attr_reader :channel

    alias original_method method

    def self.new(signature, channel, reactor, *args)
      allocate.instance_eval do
        @signature = signature
        @channel = channel
        @reactor = reactor
        initialize(*args)
        post_init
        self
      end
    end

    def initialize(*args)
    end

    def post_init
    end

    def receive_data data
      puts "............>>>#{data.length}"
    end

    def unbind
    end

    def close_connection after_writing = false
      @reactor.close_connection(@signature, after_writing)
    end

    def detach
      @reactor.unbound_connections << @signature
      @channel.channel.fdVal
    end

    def get_sock_opt level, option
      ZMachine::_get_sock_opt @signature, level, option
    end

    def set_sock_opt level, optname, optval
      ZMachine::_set_sock_opt @signature, level, optname, optval
    end

    def close_connection_after_writing
      close_connection true
    end

    def send_data data
      data = data.to_s
      size = data.bytesize if data.respond_to?(:bytesize)
      size ||= data.size
      @reactor.send_data(@signature, data.to_java_bytes)
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

    def connection_completed
    end

    def get_peername
      if peer = @reactor.peer_name(@signature)
        Socket.pack_sockaddr_in(*peer)
      end
    end

    def get_sockname
      if sock_name = @reactor.get_sock_name(@signature)
        Socket.pack_sockaddr_in(*sock_name)
      end
    end

    def reconnect server, port
      ZMachine::reconnect server, port, self
    end

    def notify_readable= mode
      @reactor.set_notify_readable(@signature, mode)
    end

    def notify_readable?
      @reactor.is_notify_readable(@signature)
    end

    def notify_writable= mode
      @reactor.set_notify_writable(@signature, mode)
    end

    def notify_writable?
      @reactor.is_notify_writable(@signature)
    end

    def pause
      ZMachine::_pause_connection @signature
    end

    def resume
      ZMachine::_resume_connection @signature
    end

    def paused?
      ZMachine::_connection_paused? @signature
    end
  end
end
