require "socket"

describe Livereload::Stream do
  let!(:server)  { TCPServer.new("localhost", 0) }
  let!(:local)  { TCPSocket.new("localhost", server.addr(true)[1]) }
  let!(:remote) { server.accept }

  let(:append) { proc { |data| received << data.dup } }
  let(:fail) { proc { raise "This should not be reached" } }

  it "can stream from/to an IO" do
    thread = Thread.new(local) do |io|
      received = []

      stream = Livereload::Stream.new(io) do |data|
        received << data.dup
        stream.write(data.upcase)
      end
      stream.write("Hi this is stream!")
      stream.loop

      received
    end

    sent = []
    sent << remote.readpartial(18)
    remote.write("Hello stream!")
    sent << remote.readpartial(13)
    remote.write("What up?!")
    sent << remote.readpartial(9)
    remote.close

    received = thread.value
    expect(received).to eq(["Hello stream!", "What up?!"])
    expect(sent).to eq(["Hi this is stream!", "HELLO STREAM!", "WHAT UP?!"])
  end

  context "exits gracefully when IO is closed remotely" do
    let(:received) { "" }

    specify "before looping" do
      remote.close

      stream = Livereload::Stream.new(local, &fail)
      stream.loop

      expect(received).to be_empty
    end

    specify "during reading" do
      remote.write "This is cool"

      io = FakeIO.new(local, read_buffer: 8)
      io.on(:read_nonblock) { remote.close unless remote.closed? }

      stream = Livereload::Stream.new(io, &append)
      stream.loop

      expect(received).to eq "This is cool"
    end

    specify "during writing" do
      data = ""
      io = FakeIO.new(local, write_buffer: 4)
      io.on(:write_nonblock) { data << remote.readpartial(100) unless remote.closed? }
      io.on(:write_nonblock) { remote.close unless remote.closed? }

      stream = Livereload::Stream.new(io, &fail)
      stream.write "This is cool."
      stream.loop

      expect(data).to eq("This")
    end

    specify "after looping" do
      count = 0

      io = FakeIO.new(local)
      io.on(:to_io) { remote.close }

      remote.write "This is cool"

      stream = Livereload::Stream.new(io, &append)
      stream.loop

      expect(received).to eq("This is cool")
    end
  end

  context "exits gracefully when IO is closed locally" do
    specify "before looping"
    specify "during reading"
    specify "during writing"
    specify "after looping"
  end

  it "deregisters from the selector if reading crashes"
  it "deregisters from the selector if writing crashes"

  it "can utilize an external selector"
end
