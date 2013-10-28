#!/usr/bin/env ruby

require 'zmachine/zmq_channel'

include ZMachine

server = ZMQChannel.new(ZMQ::REP)
#server.bind("tcp://0.0.0.0:12345")
server.bind("inproc://x")

client = ZMQChannel.new(ZMQ::REQ)
#client.connect("tcp://0.0.0.0:12345")
client.connect("inproc://x")

data = ("x" * 2048).to_java_bytes

loop do
  client.send_data([data])
  received = server.read_inbound_data.first
  puts received
  server.send_data([data])
  client.read_inbound_data
end
