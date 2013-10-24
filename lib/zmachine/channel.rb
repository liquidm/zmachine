module ZMachine
  class Channel

    attr_accessor :socket
    attr_reader   :selector
    attr_accessor :handler
    attr_accessor :reactor

    attr_reader :comm_inactivity_timeout
    attr_reader :last_comm_activity

    def initialize(selector)
      @selector = selector
      @outbound_queue = []
      @comm_inactivity_timeout = 0
      @timedout = false
      mark_active!
    end

    # assigned in seconds!!
    def comm_inactivity_timeout=(value)
      # we are in nanos
      @comm_inactivity_timeout = value * 1000_000_000
    end

    def mark_active!
      @last_comm_activity = System.nano_time
    end

    def timedout?
      @timedout
    end

    def timedout!
      @timedout = true
    end

    def was_active?(now)
      @last_comm_activity + @comm_inactivity_timeout >= now
    end

  end
end
