module ZMachine
  class FileNotFoundException < Exception
  end

  class Connection
    attr_accessor :signature

    alias original_method method

    def self.new(sig, *args)
      allocate.instance_eval do
        @signature = sig
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
      ZMachine::_close_connection @signature, after_writing
    end

    def detach
      ZMachine::_detach_fd @signature
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
      ZMachine::_send_data @signature, data, size
    end

    def error?
      errno = ZMachine::report_connection_error_status(@signature)
      case errno
      when 0
        false
      when -1
        true
      else
        ZMachine::ERRNOS[errno]
      end
    end

    def connection_completed
    end

    def get_peername
      ZMachine::_get_peername @signature
    end

    def get_sockname
      ZMachine::_get_sockname @signature
    end

    def reconnect server, port
      ZMachine::reconnect server, port, self
    end

    def notify_readable= mode
      ZMachine::_set_notify_readable @signature, mode
    end

    def notify_readable?
      ZMachine::_is_notify_readable @signature
    end

    def notify_writable= mode
      ZMachine::_set_notify_writable @signature, mode
    end

    def notify_writable?
      ZMachine::_is_notify_writable @signature
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
