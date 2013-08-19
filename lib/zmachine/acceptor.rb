module ZMachine
  class Acceptor
    attr_reader :klass
    attr_reader :args
    attr_reader :callback

    def initialize(channel, klass, *args, &block)
      @klass, @args, @callback = klass, args, block
    end

  end
end
