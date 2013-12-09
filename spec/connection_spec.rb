require 'zmachine/connection'

include ZMachine

shared_examples_for "a Connection" do

  before(:each) do
    @server = Connection.new.bind(address, port_or_type[0]) { |c| @accepted = c }
    @client = Connection.new.connect(address, port_or_type[1]) { |c| @connection = c }
  end

  after(:each) do
    @client.close
    @server.close
    ZMachine.context.destroy
  end

  let(:data) { "foo" }

  context 'triggers' do

    it 'triggers acceptable' do
      @server.channel.should_receive(:accept).and_call_original
      connection = @server.acceptable!
      expect(connection).to be_connected
      expect(@accepted).to eq(connection)
      expect(@connection).to be_a(Connection)
    end

    it 'triggers connectable' do
      @server.acceptable!
      @client.channel.should_receive(:finish_connecting).and_call_original
      @client.should_receive(:connection_completed)
      @client.connectable!
      expect(@client).to be_connected
    end

    it 'triggers writable' do
      @server.acceptable!
      @client.connectable!
      @client.send_data(data)
      @client.channel.should_receive(:write_outbound_data).and_call_original
      @client.writable!
    end

    it 'triggers readable' do
      connection = @server.acceptable!
      @client.connectable!
      @client.send_data(data)
      @client.writable!
      connection.channel.should_receive(:read_inbound_data).and_call_original
      connection.should_receive(:receive_data).with(data)
      connection.readable!
    end

  end

end

describe Connection do

  context 'TCP' do

    it_behaves_like "a Connection"

    let(:address) { "0.0.0.0" }
    let(:port_or_type) { [51635, 51635] }

  end

  context 'ZMQ' do

    it_behaves_like "a Connection"

    let(:address) { "tcp://0.0.0.0:51634" }
    let(:port_or_type) { [ZMQ::REP, ZMQ::REQ] }

  end
end
