#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'zmachine'

java_import org.zeromq.ZMQ

#set_trace_func proc { |event, file, line, id, binding, classname|
#  printf "%8s %s:%-2d %10s %8s\n", event, file, line, id, classname
#}

class EchoServer < ZMachine::Connection
  def receive_data(data)
    #puts "recv(#{data.to_a.map {|f| String.from_java_bytes(f.data) }.inspect})"
    #puts "recv(#{data.inspect})"
    send_data(data)
  end
end

ZMachine.run do
  #ZMachine.start_server("tcp://*:10000", ZMQ::PULL, EchoServer)
  ZMachine.start_server("tcp://*:10000", ZMQ::REP, EchoServer)
  #ZMachine.start_server("0.0.0.0", 10000, EchoServer)
  puts "machine running"
end
