require 'zmachine/connection'

include ZMachine

describe Connection do

  before(:each) do
    @server = Connection.new.bind("0.0.0.0", 0)
    @port = @server.channel.socket.socket.local_port
    @client = Connection.new.connect("0.0.0.0", @port)
  end

  after(:each) do
    @client.close
    @server.close
  end

  let(:data) { "foo" }

  context 'triggers' do

    it 'triggers acceptable' do
      @server.channel.should_receive(:accept).once.and_call_original
      @server.should_receive(:connection_accepted).once
      connection = @server.acceptable!
      expect(connection).to be_connected
    end

    it 'triggers connectable' do
      @server.acceptable!
      @client.channel.should_receive(:finish_connecting).once.and_call_original
      @client.should_receive(:connection_completed).once
      @client.connectable!
      expect(@client).to be_connected
    end

    it 'triggers writable' do
      @server.acceptable!
      @client.connectable!
      @client.send_data(data.to_java_bytes)
      @client.channel.should_receive(:write_outbound_data).and_call_original
      @client.writable!
    end

    it 'triggers readable' do
      connection = @server.acceptable!
      @client.connectable!
      @client.send_data(data.to_java_bytes)
      @client.writable!
      connection.channel.should_receive(:read_inbound_data).and_call_original
      connection.should_receive(:receive_data).once
      connection.readable!
    end

  end
end
