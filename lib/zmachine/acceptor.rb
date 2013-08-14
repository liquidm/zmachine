module ZMachine
  class Acceptor < Struct.new(:socket, :klass, :args, :callback)
  end
end
