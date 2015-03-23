require "socket"

describe Livereload::Stream do
  it "can stream from/to an IO" do
    local, remote = UNIXSocket.pair

    thread = Thread.new do
      received = []

      stream = Livereload::Stream.new(local) do |data|
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

  it "can stream data from an IO in chunks"
  it "can stream data to an IO"

  it "exits gracefully when IO is closed on the local end"
  it "exits gracefully when IO is closed on the remote end"

  it "deregisters from the selector if something goes amiss"
  it "deregisters from the selector if socket is closed"
  it "can utilize an external selector"
end
