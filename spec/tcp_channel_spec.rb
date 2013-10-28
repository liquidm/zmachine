require 'zmachine/tcp_channel'

include ZMachine

describe ZMachine::TCPChannel do

  before(:each) do
    @server = TCPChannel.new
    @server.bind("0.0.0.0", 0)
    @port = @server.socket.socket.local_port
    @client = TCPChannel.new
    @client.connect("0.0.0.0", @port)
  end

  after(:each) do
    @client.close
    @server.close
  end

  let(:data) { "foo" }

  context '#bind' do

    it 'binds a server socket' do
      expect(@server).to be_bound
    end

    it 'accepts client connections' do
      channel = @server.accept
      expect(channel).to be_a(TCPChannel)
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
      @client.finish_connecting
      @client.send_data(data.to_java_bytes)
    end

    it 'writes outbound buffers to the socket' do
      expect(@client.write_outbound_data).to eq(true)
    end

    it 'receives data sent from the client' do
      @client.write_outbound_data
      received = @channel.read_inbound_data
      expect(received).to eq(data)
    end

    it 'receives data sent from the server' do
      @client.write_outbound_data
      received = @channel.read_inbound_data
      @channel.send_data(data.to_java_bytes)
      @channel.write_outbound_data
      received = @client.read_inbound_data
      expect(received).to eq(data)
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
      @client.send_data(data.to_java_bytes)
      @client.close_after_writing
      expect(@client).to be_connected
      @client.write_outbound_data
      expect(@client).not_to be_connected
    end

  end

end
