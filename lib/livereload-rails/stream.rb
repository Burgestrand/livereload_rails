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
    def initialize(io, selector: NIO::Selector.new)
      @io = io
      @selector = selector

      @read_handler = Proc.new
      @update_handler = method(:update)

      @input_buffer = "".b
      @output_queue = Queue.new
      @output_buffer = "".b
    end

    # Queue a message to be sent later on the stream.
    #
    # There is no guarantee that the message will arrive. If you want a receipt
    # of any kind you will need to wait for a reply.
    #
    # @param [String] message
    def write(message)
      @output_queue << message.to_s
      @selector.wakeup
    end

    # Close the connection immediately.
    def close
      @io.close unless @io.closed?
    end

    # Continously stream data to/from the underlying IO.
    def loop
      register(:rw) # w in case we have any writes pending.

      while @selector.registered?(@io)
        # TODO: timeouts, see https://github.com/celluloid/nio4r/issues/63
        @selector.select do |monitor|
          monitor.value.call(monitor)
        end
      end
    end

    private

    def register(interests)
      @selector.deregister(@io)

      unless @io.closed?
        monitor = @selector.register(@io, interests)
        monitor.value = @update_handler
        monitor
      end
    end

    # @note this is always the same object, but it might be refilled with data from the output queue.
    # @return [String] the current output buffer.
    def output_buffer
      if @output_buffer.empty? and @output_queue.length > 0
        @output_buffer.replace(@output_queue.pop)
      end

      @output_buffer
    end

    # This method takes care of reading and writing as much data to/from the IO
    # in a single pass.
    #
    # @param [NIO::Monitor] monitor
    def update(monitor)
      next_interests = :r

      if monitor.readable?
        begin
          # Read as much data as possible.
          until @io.closed?
            @io.read_nonblock(READ_CHUNK, @input_buffer)
            @read_handler[@input_buffer]
          end
        rescue IO::WaitReadable
          # No op. Next interest is always at least a read.
        ensure
          @input_buffer.clear
        end
      end

      begin
        # Write as much data as possible.
        while not @io.closed? and output_buffer.length > 0
          bytes_written = @io.write_nonblock(output_buffer)
          output_buffer[0, bytes_written] = EMPTY
        end
      rescue IO::WaitWritable
        next_interests = :rw
      end

      if @io.closed?
        monitor.close
      elsif next_interests != monitor.interests
        register(next_interests)
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
