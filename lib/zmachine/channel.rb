module ZMachine
  class Channel

    attr_reader :socket
    attr_reader :signature
    attr_reader :selector
    attr_accessor :handler

    def initialize(socket, signature, selector)
      @socket = socket
      @signature = signature
      @selector = selector
    end

    def register
      @channel_key ||= @selectable_channel.register(@selector, current_events, self)
    end

  end
end
