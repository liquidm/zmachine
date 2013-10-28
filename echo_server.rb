#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'madvertise/boot'
require 'zmachine'

$log.level = :debug
ZMachine.logger = $log
ZMachine.debug = true

#set_trace_func proc { |event, file, line, id, binding, classname|
#  printf "%8s %s:%-2d %10s %8s\n", event, file, line, id, classname
#}

class ZMQEchoServer < ZMachine::Connection
  def receive_data(buffer)
    send_data(buffer)
  end
end

class TCPEchoServer < ZMachine::Connection
  def receive_data(buffer)
    send_data(buffer)
  end
end

ZMachine.run do
  ZMachine.start_server("tcp://*:10000", ZMQ::ROUTER, ZMQEchoServer) do |handler|
    handler.channel.identity = "server"
  end
  #ZMachine.start_server("0.0.0.0", 10000, TCPEchoServer)
  puts "machine running"
end
