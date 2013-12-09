require "socket"

module EchoMock
  def self.start(port = 6380)
    server = TCPServer.new("127.0.0.1", port)
    loop do
      session = server.accept
      while line = session.gets
        session.write(line)
        session.write("\r\n")
      end
    end
  end

  module Helper
    def echo_mock
      begin
        pid = fork do
          trap("TERM") { exit }
          EchoMock.start
        end
        sleep 1 # Give time for the socket to start listening.
        yield
      ensure
        if pid
          Process.kill("TERM", pid)
          Process.wait(pid)
        end
      end
    end
  end
end
