require "socket"

describe Livereload::Stream do
  # Unidirectional pipe for both reading and writing.
  let(:pipe)  { UNIXSocket.pipe }
  let(:left)  { pipe[0] }
  let(:right) { pipe[1] }

  it "can read data non-blockingly from an IO"
  it "can read data in multiple passes"

  it "can write data non-blockingly to an IO"
  it "can write data in multiple passes"

  it "exits gracefully when IO is closed on the local end"
  it "exits gracefully when IO is closed on the remote end"

  it "deregisters from the selector if something goes amiss"
  it "deregisters from the selector if socket is closed"
  it "can utilize an external selector"
end
