class FakeIO
  def initialize(io, read_buffer: 10, write_buffer: 10)
    @io = io

    @read_buffer = read_buffer
    @write_buffer = write_buffer
  end

  attr_accessor :read_buffer
  attr_accessor :write_buffer

  def on(method)
    extend(Module.new {
      define_method(method) do |*args|
        super(*args).tap { yield }
      end
    })
  end

  def read_nonblock(maxlength, buffer)
    @io.read_nonblock(read_buffer || maxlength, buffer)
  end

  def write_nonblock(data)
    data = data[0, write_buffer] if write_buffer
    @io.write_nonblock(data)
  end

  def close
    @io.close
  end

  def closed?
    @io.closed?
  end

  def to_io
    @io
  end
end
