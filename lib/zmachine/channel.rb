module ZMachine
  class Channel

    attr_accessor :socket
    attr_reader :selector
    attr_accessor :handler
    attr_accessor :reactor

    def initialize(selector)
      @selector = selector
      @outbound_queue = []
    end

  end
end
