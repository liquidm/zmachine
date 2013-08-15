#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'zmachine'

java_import org.zeromq.ZMQ

#set_trace_func proc { |event, file, line, id, binding, classname|
#  printf "%8s %s:%-2d %10s %8s\n", event, file, line, id, classname
#}

class Echo < ZMachine::Connection
  def connection_completed
    send_data("foo")
  end

  def receive_data(data)
    puts data
    send_data(Time.now.to_s)
  end
end

ZMachine.run {
  ZMachine.connect("tcp://127.0.0.1:10000", ZMQ::REQ, Echo)
}
