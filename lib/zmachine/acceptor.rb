module ZMachine
  class Acceptor
    attr_reader :klass
    attr_reader :args
    attr_reader :callback

    def initialize(channel, klass, *args )
      @klass, @args, @callback = klass, args[0...-1], args.last
      @channel = channel
    end

    def unbind
    end

    def close
      @channel.close
    end

  end
end
