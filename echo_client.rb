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

$i = 0

class ZMQEcho < ZMachine::Connection
  def connection_completed
    send_msg
  end

  def receive_data(data)
    puts "recv(#{data.to_a.map {|f| String.from_java_bytes(f.data) }.inspect})"
    send_msg
  end

  def send_msg
    msg = ZMsg.new_string_msg($i.to_s)
    msg.wrap(ZFrame.new("server"))
    send_data(msg)
    $i += 1
  end
end

class TCPEcho < ZMachine::Connection
  def connection_completed
    send_data(Time.now.to_s)
    sleep(0.5)
  end

  def receive_data(data)
    puts "receive_data(#{data.inspect})"
    send_data(Time.now.to_s)
  end
end

ZMachine.run do
  #ZMachine.connect("tcp://127.0.0.1:10000", ZMQ::ROUTER, ZMQEcho) do |handler|
  #  handler.channel.identity = "client"
  #end
  ZMachine.connect("127.0.0.1", 10000, TCPEcho)
end
