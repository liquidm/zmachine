module ZMachine
  class Connection

    attr_accessor :channel

    extend Forwardable
    def_delegator :@channel, :close_connection
    def_delegator :@channel, :get_sock_opt
    def_delegator :@channel, :set_sock_opt
    def_delegator :@channel, :send_data

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

    def receive_data data
    end

    def unbind
    end

    def connection_completed
    end

    def close_connection_after_writing
      close_connection(true)
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
  end
end
