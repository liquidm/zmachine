#!/usr/bin/env ruby

require 'zmachine/tcp_channel'

include ZMachine

server = TCPChannel.new
server.bind("0.0.0.0", 12345)

client = TCPChannel.new
client.connect("0.0.0.0", 12345)

channel = server.accept
client.finish_connecting

data = ("x" * 2048).freeze

loop do
  client.send_data(data)
  client.write_outbound_data
  received = channel.read_inbound_data
  puts received
  channel.send_data(received)
  channel.write_outbound_data
  client.read_inbound_data
end
