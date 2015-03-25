require "thread"
require "nio"

module Livereload
  # A non-blocking connection.
  class Stream
    READ_CHUNK = 1024 * 10
    EMPTY = "".freeze

    # @example
    #   stream = Stream.new(io) do |input|
    #     # handle input
    #   end
    #   stream.loop
    #
    # @param [#read_nonblock, #write_nonblock] io
    #
    # @yield [input] whenever there is input to be consumed.
    # @yieldparam input [String] streaming input data.
    def initialize(io)
      @io = io

      @read_block = Proc.new
      @stream_handler = method(:stream_handler)
      @wakeup_handler = method(:wakeup_handler)

      @input_buffer = "".b
      @output_buffer = "".b

      @output_queue = []
      @mutex = Mutex.new
      @wakeup, @waker = IO.pipe
    end

    attr_reader :io

    # Queue a message to be sent later on the stream.
    #
    # There is no guarantee that the message will arrive. If you want a receipt
    # of any kind you will need to wait for a reply.
    #
    # @param [String] message
    def write(message)
      @mutex.synchronize do
        @output_queue.push(message)
        @waker.write("\0")
      end
    end

    # Close the connection immediately.
    #
    # TODO: SO_LINGER, close before or after sending outgoing data?
    def close
      @io.close unless @io.closed?
    end

    # Continously stream data to/from the underlying IO.
    def loop(selector = NIO::Selector.new)
      return if @io.closed?

      @selector = selector

      selector.register(@wakeup, :r).value = @wakeup_handler
      register_stream(:r)

      while selector.registered?(@io)
        # TODO: timeouts, see https://github.com/celluloid/nio4r/issues/63
        @selector.select do |monitor|
          monitor.value.call(monitor)
        end
      end
    ensure
      @selector = nil
      selector.deregister(@io)
      selector.deregister(@wakeup)
    end

    private

    def output_buffer
      if @output_buffer.empty? and @output_queue.length > 0
        message = @mutex.synchronize { @output_queue.pop }
        @output_buffer.replace(message)
      end

      @output_buffer
    end

    def register_stream(interests)
      if @stream_monitor
        if @stream_monitor.interests == interests
          return @stream_monitor
        else
          @stream_monitor.close
        end
      end

      @stream_monitor = @selector.register(@io, interests)
      @stream_monitor.value = @stream_handler
      @stream_monitor
    end

    def wakeup_handler(monitor)
      monitor.io.read(monitor.io.stat.size)
      register_stream(:rw)
    end

    # This method takes care of reading and writing as much data to/from the IO
    # in a single pass.
    def stream_handler(monitor)
      next_interests = :r

      if monitor.readable?
        begin
          # Read as much data as possible.
          until @io.closed?
            @io.read_nonblock(READ_CHUNK, @input_buffer)
            @read_block[@input_buffer]
          end
        rescue IO::WaitReadable
          # No op. Next interest is always at least a read.
        ensure
          @input_buffer.clear
        end
      end

      begin
        # Write as much data as possible.
        while not @io.closed? and output_buffer.bytesize > 0
          bytes_written = @io.write_nonblock(output_buffer)
          output_buffer[0, bytes_written] = EMPTY
        end
      rescue IO::WaitWritable
        next_interests = :rw
      end

      if @io.closed?
        monitor.close
      else
        register_stream(next_interests)
      end
    rescue EOFError, IOError, Errno::EPIPE, Errno::ECONNRESET, Errno::EPROTOTYPE
      # Swallow errors.
      monitor.close
    ensure
      # Other errors bubble.
      monitor.close if $!
    end
  end
end
