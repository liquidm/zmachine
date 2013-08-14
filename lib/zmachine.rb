require 'socket'
require 'zmachine/reactor'
require 'zmachine/connection'

java_import java.io.FileDescriptor
java_import java.nio.channels.SocketChannel
java_import java.lang.ThreadLocal

module ZMachine
  class ConnectionError < RuntimeError; end
  class ConnectionNotBound < RuntimeError; end
  class UnknownTimerFired < RuntimeError; end
  class Unsupported < RuntimeError; end

  ERRNOS = Errno::constants.grep(/^E/).inject(Hash.new(:unknown)) { |hash, name|
    errno = Errno.__send__(:const_get, name)
    hash[errno::Errno] = errno
    hash
  }

  def self.instance
    @reactor ||= ThreadLocal.new
    @reactor.set(Reactor.new) unless @reactor.get
    @reactor.get
  end

  class << self
    extend Forwardable
    def_delegator :instance, :run
    def_delegator :instance, :next_tick
    def_delegator :instance, :start_server
  end

  def self.run_block(&block)
    pr = proc {
      block.call
      ZMachine::stop
    }
    run(&pr)
  end

  def self.stop_event_loop
  end

  def self.set_quantum(millis)
  end

  def self.set_max_timers(ct)
  end

  def self.get_max_timers
  end

  def self.connection_count
  end

  def self.heartbeat_interval
  end

  def self.heartbeat_interval=(time)
  end

end
