module ZMachine
  class Acceptor < Struct.new(:selectable_channel, :klass, :args, :callback)
    def close
      selectable_channel.close
    end

    def socket
      if selectable_channel.java_is_a?(org.zeromq.Socket)
        selectable_channel.fd
      else
        selectable_channel
      end
    end
  end
end
