#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'zmachine'

java_import org.zeromq.ZMQ
java_import org.zeromq.ZMsg
java_import org.zeromq.ZFrame

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

ZMachine.run {
  ZMachine.connect("tcp://127.0.0.1:10000", ZMQ::ROUTER, ZMQEcho) do |handler|
    handler.channel.identity = "client"
  end
  #ZMachine.connect("127.0.0.1", 10000, TCPEcho)
}

#ctx = ZContext.new
#socket = ctx.create_socket(ZMQ::ROUTER)
#socket.connect("tcp://127.0.0.1:10000")
#socket.identity = "client".to_java_bytes

#sleep(1)

#loop do
#  msg = ZMsg.new_string_msg($i.to_s)
#  msg.wrap(ZFrame.new("server"))
#  msg.java_send(:send, [org.zeromq.ZMQ::Socket], socket)
#  $i += 1
#  break if $i > 100
#  #puts ZMsg.recvMsg(socket).inspect
#end

#socket.close
#ctx.destroy
