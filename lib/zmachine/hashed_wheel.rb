java_import java.lang.System

module ZMachine

  class HashedWheelTimeout
    attr_reader :deadline
    attr_reader :callback

    def initialize(deadline, &block)
      @deadline = deadline
      @callback = block
      @canceled = false
    end

    def cancel
      @canceled = true
    end

    def canceled?
      @canceled
    end
  end

  class HashedWheel
    attr_reader :slots
    attr_accessor :last

    def initialize(number_of_slots, tick_length, start_time = System.nano_time)
      @slots = Array.new(number_of_slots) { [] }
      @tick_length = tick_length * 1_000_000_000
      @last = start_time
      @current_tick = 0
    end

    def add(timeout, &block)
      timeout *= 1_000_000_000 # s to ns
      ticks = timeout / @tick_length
      slot = (@current_tick + ticks) % @slots.length
      deadline = System.nano_time + timeout
      @slots[slot] << HashedWheelTimeout.new(deadline, &block)
    end

    def reset(time = nil)
      @slots = Array.new(@slots.length) { [] }
      @current_tick = 0
      @last = time || System.nano_time
    end

    # returns all timeouts
    def advance(now = nil)
      now ||= System.nano_time
      passed_ticks = (now - @last) / @tick_length
      result = []
      begin
        @current_tick %= @slots.length
        @slots[@current_tick].delete_if do |timeout|
          result << timeout if timeout.deadline < now
        end
        @current_tick += 1
        passed_ticks -= 1
      end while passed_ticks > 0
      @last = now
      result.reject do |timeout|
        timeout.canceled?
      end
    end

  end
end
