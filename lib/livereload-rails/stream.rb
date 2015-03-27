require "thread"
require "nio"

module Livereload
  # A non-blocking connection.
  class Stream
    READ_CHUNK = 1024 * 10
    EMPTY = "".freeze
    SWALLOW_ERRORS = [EOFError, IOError, Errno::EPIPE, Errno::ECONNRESET, Errno::EPROTOTYPE]

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
      @io_writer = @io.dup

      @read_block = Proc.new

      @input_buffer = "".b
      @output_buffer = "".b
      @output_queue = []
      @mutex = Mutex.new

      @wakeup, @waker = IO.pipe
    end

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
      @io_writer.close unless @io_writer.closed?
      @waker.close unless @waker.closed?
      @wakeup.close unless @wakeup.closed?
    end

    # @return [Boolean] true if stream is closed.
    def closed?
      @io.closed?
    end

    # @param [NIO::Selector] selector
    def loop(selector = NIO::Selector.new)
      @looping = ! closed?
      return unless @looping

      wakeup_monitor = selector.register(@wakeup, :r)
      wakeup_monitor.value = handler_for(:wakeup_handler)

      read_monitor = selector.register(@io, :r)
      read_monitor.value = handler_for(:read_handler)

      register_writer(selector)

      while @looping
        selector.select { |monitor| monitor.value.call(monitor) }
      end
    ensure
      selector.deregister(@io)
      selector.deregister(@io_writer)
      selector.deregister(@wakeup)
    end

    private

    # @note The returned string is always the same object.
    # @return [String] the current output buffer, possibly refilled from the output queue.
    def output_buffer
      if @output_buffer.empty? and @output_queue.length > 0
        message = @mutex.synchronize { @output_queue.pop }
        @output_buffer.replace(message)
      end

      @output_buffer
    end

    def register_writer(selector)
      return if selector.registered?(@io_writer)
      return if output_buffer.empty?

      write_monitor = selector.register(@io_writer, :w)
      write_monitor.value = handler_for(:write_handler)
    end

    def handler_for(method_name)
      handler_method = method(method_name)

      lambda do |monitor|
        begin
          handler_method.call(monitor)
        rescue IO::WaitReadable, IO::WaitWritable
          # No op. Let monitor continue be selected.
        rescue *SWALLOW_ERRORS
          @looping = false
        ensure
          @looping = false if $!
        end
      end
    end

    def wakeup_handler(monitor)
      @wakeup.read(@wakeup.stat.size)
      register_writer(monitor.selector)
    end

    def write_handler(monitor)
      until output_buffer.empty?
        bytes_written = @io.write_nonblock(output_buffer)
        output_buffer[0, bytes_written] = EMPTY
      end

      monitor.close # write_nonblock did not raise, so we have no more output.
    end

    def read_handler(monitor)
      Kernel.loop do
        @io.read_nonblock(READ_CHUNK, @input_buffer)
        @read_block[@input_buffer]
      end
    ensure
      @input_buffer.clear
    end
  end
end
