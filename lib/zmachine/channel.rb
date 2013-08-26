module ZMachine
  class Channel

    attr_reader :socket
    attr_reader :selector
    attr_accessor :handler

    def initialize(selector)
      @selector = selector
      @outbound_queue = []
    end

  end
end
