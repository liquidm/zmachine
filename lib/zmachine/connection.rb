module ZMachine
  class FileNotFoundException < Exception
  end

  class Connection
    attr_accessor :signature
    attr_accessor :channel

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

    def get_sock_opt(level, option)
      ZMachine::_get_sock_opt @signature, level, option
    end

    def set_sock_opt(level, optname, optval)
      ZMachine::_set_sock_opt @signature, level, optname, optval
    end

    def close_connection_after_writing
      close_connection true
    end

    # TODO add more d attributes (badpokerface)
    def send_data(d1, d2=nil, d3=nil, d4=nil)
      @reactor.send_data(@signature, d1, d2, d3, d4)
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
      if peer = @channel.peer_name
        ::Socket.pack_sockaddr_in(*peer)
      end
    end

    def get_sockname
      if sock_name = @channel.sock_name
        ::Socket.pack_sockaddr_in(*sock_name)
      end
    end

    def reconnect(server, port)
      ZMachine::reconnect(server, port, self)
    end

    def notify_readable=(mode)
      @channel.notify_readable = mode
    end

    def notify_readable?
      @channel.notify_readable
    end

    def notify_writable=(mode)
      @channel.notify_writable = mode
    end

    def notify_writable?
      @channel.notify_writable
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
