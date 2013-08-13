#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'zmachine'

class EchoServer < ZMachine::Connection
  def receive_data(data)
    send_data(data)
  end
end

ZMachine.run do
  # hit Control + C to stop
  Signal.trap("INT")  { ZMachine.stop }
  Signal.trap("TERM") { ZMachine.stop }

  ZMachine.start_server("0.0.0.0", 10000, EchoServer)
  puts "machine running"
end
