require 'zmachine/zmq_channel'

include ZMachine

describe ZMachine::ZMQChannel do

  before(:each) do
    @server = ZMQChannel.new(ZMQ::REP)
    @port = @server.bind("tcp://*:*")
    @client = ZMQChannel.new(ZMQ::REQ)
    @client.connect("tcp://0.0.0.0:#{@port}")
  end

  after(:each) do
    @client.close
    @server.close
  end

  after(:all) do
    ZMachine.context.destroy
  end

  let(:data) { "foo" }

  context '#bind' do

    it 'binds a server socket' do
      expect(@server).to be_bound
    end

  end

  context '#connect' do

    it 'connects to a server socket' do
      expect(@client).to be_connected
    end

  end

  context '#send/recv' do

    it 'writes outbound buffers to the socket' do
      @client.send_data([data.to_java_bytes])
      expect(@client.write_outbound_data).to eq(true)
    end

    it 'receives data sent from the client' do
      @client.send_data([data.to_java_bytes])
      @client.write_outbound_data
      received = String.from_java_bytes(@server.read_inbound_data.first)
      expect(received).to eq(data)
    end

    it 'receives data sent from the server' do
      @client.send_data([data.to_java_bytes])
      @client.write_outbound_data
      received = String.from_java_bytes(@server.read_inbound_data.first)
      @server.send_data([data.to_java_bytes])
      @server.write_outbound_data
      received = String.from_java_bytes(@client.read_inbound_data.first)
      expect(received).to eq(data)
    end

    it 'sends and receives multipart messages' do
      parts = %w(foo bar baz)
      @client.send_data(parts.map(&:to_java_bytes))
      @client.write_outbound_data
      received = @server.read_inbound_data.map do |part|
        String.from_java_bytes(part)
      end
      expect(received).to eq(parts)
    end

    it 'queues data when ZMQ is MIA' do
      socket = @client.socket
      # https://github.com/jruby/jruby/wiki/Persistence#deprecating-proxy-caching
      Java::OrgZeromq::ZMQ::Socket.__persistent__ = true
      socket.stub(:send_byte_array) { socket.unstub(:send_byte_array); raise ZMQException.new(nil) }
      @client.send_data([data.to_java_bytes])
      expect(@client.can_send?).to eq(true)
      @client.write_outbound_data
      expect(@client.can_send?).to eq(false)
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

    it 'closes the connection after writing' do
      @client.send_data([data.to_java_bytes])
      @client.close_after_writing
      @client.write_outbound_data
      expect(@client).not_to be_connected
    end

  end

  it 'has no concept of a peer' do
    expect{@client.peer}.to raise_error(RuntimeError)
  end

end
