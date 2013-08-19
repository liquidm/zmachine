module ZMachine
  class Channel

    attr_reader :socket
    attr_reader :signature
    attr_reader :selector
    attr_accessor :handler

    def initialize(signature, selector)
      @signature = signature
      @selector = selector
      @outbound_queue = []
    end

  end
end
