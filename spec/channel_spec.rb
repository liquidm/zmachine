require 'zmachine/tcp_channel'
require 'zmachine/zmq_channel'

include ZMachine

shared_examples_for "a Channel" do

  context '#bind' do

    it 'binds a server socket' do
      expect(@server).to be_bound
    end

    it 'accepts client connections' do
      channel = @server.accept
      expect(channel).to be_a(klass)
      expect(channel).to be_connected
    end

  end

  context '#connect' do

    it 'connects to a pending server socket' do
      expect(@client).to be_connection_pending
    end

    it 'connects to an accepted server socket' do
      @server.accept
      @client.finish_connecting
      expect(@client).to be_connected
    end

  end

  context '#send/recv' do

    before(:each) do
      @channel = @server.accept
      @channel.raw = false
      @client.finish_connecting
    end

    it 'writes outbound buffers to the socket' do
      @client.send_data(data)
      expect(@client.write_outbound_data).to eq(true)
    end

    it 'receives data sent from the client' do
      @client.send_data(data)
      @client.write_outbound_data
      received = @channel.read_inbound_data
      expect(received.to_s).to eq(data.to_s)
    end

    it 'receives data sent from the server' do
      @client.send_data(data)
      @client.write_outbound_data
      received = @channel.read_inbound_data
      @channel.send_data(data)
      @channel.write_outbound_data
      received = @client.read_inbound_data
      expect(received.to_s).to eq(data.to_s)
    end

  end

  context '#close' do

    it 'closes the client connection' do
      @client.close
      expect(@client).to be_closed
    end

    it 'closes the server connection' do
      @server.close
      expect(@server).to be_closed
    end

    it 'closes the accepted connection' do
      channel = @server.accept
      channel.close
      expect(channel).to be_closed
    end

    it 'closes the connection after writing' do
      channel = @server.accept
      @client.finish_connecting
      @client.send_data(data)
      @client.close(true)
      expect(@client).to be_connected
      @client.write_outbound_data
      expect(@client).not_to be_connected
    end

  end

end

describe TCPChannel do

  it_behaves_like "a Channel"

  let(:klass) { TCPChannel }
  let(:address) { "0.0.0.0" }
  let(:port_or_type) { [51635, 51635] }

  before(:each) do
    @server = klass.new
    @server.bind(address, port_or_type[0])
    @client = klass.new
    @client.connect(address, port_or_type[1])
  end

  after(:each) do
    @client.close
    @server.close
    ZMachine.context.destroy
  end

  let(:data) { "foo".to_java_bytes }

  it 'has the correct peer information' do
    expect(@client.peer).to eq([port_or_type[0], address])
    channel = @server.accept
    @client.finish_connecting
    socket = @client.socket.socket
    expect(channel.peer).to eq([socket.local_port, socket.local_address.host_address])
  end

  context '#send/recv' do

    it 'reads data after server has closed connection' do
      channel = @server.accept
      @client.finish_connecting
      channel.send_data(data)
      channel.close(true)
      expect(channel).to be_connected
      channel.write_outbound_data
      expect(channel).not_to be_connected
      expect(@client).to be_connected
      @client.read_inbound_data
      expect{@client.read_inbound_data}.to raise_error(IOException)
    end

  end

end

describe ZMQChannel do

  it_behaves_like "a Channel"

  let(:klass) { ZMQChannel }
  let(:address) { "tcp://0.0.0.0:51634" }
  let(:port_or_type) { [ZMQ::REP, ZMQ::REQ] }

  before(:each) do
    @server = klass.new
    @server.bind(address, port_or_type[0])
    @client = klass.new
    @client.connect(address, port_or_type[1])
    @client.raw = false
  end

  after(:each) do
    @client.close
    @server.close
    ZMachine.context.destroy
  end

  let(:data) { "foo".to_java_bytes }

  it 'has no concept of a peer' do
    expect{@client.peer}.to raise_error(RuntimeError)
  end

end
