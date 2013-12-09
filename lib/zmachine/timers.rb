module ZMachine
  class Timer

    attr_accessor :interval

    def initialize(interval, callback=nil, &block)
      @interval = interval
      @callback = callback || block
      schedule
    end

    def schedule
      @timer = ZMachine.add_timer(@interval, method(:fire))
    end

    def fire
      @callback.call
    end

    def cancel
      @timer.cancel
    end
  end

  class PeriodicTimer < Timer

    def fire
      super
      schedule
    end

  end
end
