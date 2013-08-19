#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'zmachine'

java_import org.zeromq.ZMQ
java_import org.zeromq.ZMsg

#set_trace_func proc { |event, file, line, id, binding, classname|
#  printf "%8s %s:%-2d %10s %8s\n", event, file, line, id, classname
#}

class ZMQEcho < ZMachine::Connection
  def connection_completed
    send_data(ZMsg.new_string_msg(Time.now.to_s))
  end

  def receive_data(data)
    puts "receive_data(#{data.inspect})"
    send_data(ZMsg.new_string_msg(Time.now.to_s))
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

ZMachine.run {
  ZMachine.connect("tcp://127.0.0.1:10000", ZMQ::REQ, ZMQEcho)
  #ZMachine.connect("127.0.0.1", 10000, TCPEcho)
}

#ctx = ZContext.new
#socket = ctx.create_socket(ZMQ::PUSH)
#socket = ctx.create_socket(ZMQ::REQ)
#socket.connect("tcp://127.0.0.1:10000")

#i = 0

#while true
#  msg = ZMsg.new_string_msg(i.to_s)
#  puts "send(#{msg.to_a.map {|f| String.from_java_bytes(f.data) }.inspect})"
#  msg.java_send(:send, [org.zeromq.ZMQ::Socket], socket)
#  #puts ZMsg.recv_msg(socket).inspect
#  i += 1
#end
