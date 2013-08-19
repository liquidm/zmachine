module ZMachine
  class Acceptor
    attr_reader :klass
    attr_reader :args

    def initialize(channel, klass, *args, &block)
      @klass, @args = klass, args
    end

  end
end
