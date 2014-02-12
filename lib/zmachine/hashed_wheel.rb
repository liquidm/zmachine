$CLASSPATH << File.expand_path("../../../java", __FILE__)
puts $CLASSPATH.inspect

module ZMachine
  HashedWheel = Java::ComLiquidmZmachine::HashedWheel
end
