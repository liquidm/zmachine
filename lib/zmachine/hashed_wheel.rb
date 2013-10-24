module ZMachine

  class HashedWheelTimeout
    attr_accessor :round
    attr_reader :deadline
    attr_reader :callback
    def initialize(round, deadline, &block)
      @round = round
      @deadline = deadline
      @callback = block
    end
  end

  class HashedWheel

    attr_reader :slots
    attr_accessor :last

    def initialize(number_of_slots, tick_length, start_time = System.nano_time)
      @slots = Array.new(number_of_slots) { [] }
      @tick_length = tick_length * 1_000_000
      @last = start_time
      @current_tick = 0

      @next = nil
    end

    def next_deadline
      return Float::INFINITY if !@next
      @next.deadline
    end

    def add(timeout, &block)
      timeout *= 1_000_000 # ms to ns
      idx =  (timeout / @tick_length) % @slots.length
      round = (timeout / @tick_length) / @slots.length
      @slots[idx] << hwt = HashedWheelTimeout.new(round, System.nano_time + timeout, &block)
      if !@next
        @next = hwt
      else
        @next = hwt if @next.deadline > hwt.deadline
      end
      hwt
    end

    def reset(time = System.nano_time)
      @slots = Array.new(@slots.length) { [] }
      @current_tick = 0
      @last = time
    end

    # returns all timeouts
    def advance(now = System.nano_time)
      # how many tickts have passed?
      passed_ticks = (now - @last) / @tick_length
      round = 0
      result = []
      begin
        q, @current_tick = @current_tick.divmod slots.length
        round += q
        # collect timeouts
         @slots[@current_tick].delete_if do |timeout|
          timeout.round -= round
          result << timeout if timeout.round <= 0 && timeout.deadline < now
        end
        @current_tick += 1
        passed_ticks -= 1
      end while passed_ticks > 0
      @last = now
      result
    end

  end
end



