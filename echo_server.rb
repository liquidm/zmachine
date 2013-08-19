#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'zmachine'

java_import org.zeromq.ZMQ
java_import org.zeromq.ZFrame

#set_trace_func proc { |event, file, line, id, binding, classname|
#  printf "%8s %s:%-2d %10s %8s\n", event, file, line, id, classname
#}

class EchoServer < ZMachine::Connection
  def receive_data(msg)
    #origin = msg.unwrap
    puts "recv(#{msg.to_a.map {|f| String.from_java_bytes(f.data) }.inspect})"
    #msg = ZMsg.new_string_msg("ok")
    #msg.wrap(origin)
    #send_data(msg)
  end
end

ZMachine.run do
  ZMachine.start_server("tcp://*:10000", ZMQ::PULL, EchoServer) do |handler|
    handler.channel.identity = "server"
  end
  #ZMachine.start_server("0.0.0.0", 10000, EchoServer)
  puts "machine running"
end

#ctx = ZContext.new
#socket = ctx.create_socket(ZMQ::ROUTER)
#socket.bind("tcp://127.0.0.1:10000")
#socket.identity = "server".to_java_bytes

#loop do
#  puts socket.events.inspect
#  msg = ZMsg.recvMsg(socket)
#  puts "recv(#{msg.to_a.map {|f| String.from_java_bytes(f.data) }.inspect})"
#end
