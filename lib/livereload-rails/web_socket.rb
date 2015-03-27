require "websocket"
require "thread"
require "nio"

# TODO: Global flag could interfere with other code.
::WebSocket.should_raise = true

module Livereload
  # Embodies a WebSocket connection as a separate thread.
  class WebSocket
    PING_TIMEOUT = 1

    class << self
      # Same as #initialize, but first checks if the request is a websocket upgrade.
      #
      # @example
      #   WebSocket.from_rack(env) do |ws|
      #     …
      #     ws.on(:open)    { … }
      #     ws.on(:message) { … }
      #     ws.on(:close)   { … }
      #   end
      #
      # @return [WebSocket, nil] a websocket instance, or nil if request was not a websocket.
      def from_rack(env, &block)
        new(env, &block) if env["HTTP_UPGRADE"] == "websocket"
      end
    end

    # @param env a rack environment hash
    def initialize(env)
      raise ArgumentError, "no block given" unless block_given?

      @env = env
      @handlers = { open: Set.new, close: Set.new, message: Set.new }
      @handshake = ::WebSocket::Handshake::Server.new(secure: false)

      queue = Queue.new

      @thread = Thread.new do
        begin
          finish_initialize = proc do |event|
            finish_initialize = nil
            queue << event
          end

          hijack do
            yield self
            finish_initialize[:connected]
          end
        ensure
          finish_initialize[$!] if finish_initialize
        end
      end

      message = queue.pop
      raise message if message.is_a?(Exception)
    end

    attr_reader :thread

    # Register an event handler.
    #
    # @example
    #   handler = websocket.on(:open) { … }
    #
    # @note If an event handler raises an error, handlers after it will not run.
    # @param [Symbol] event (one of :open, :close, :message)
    def on(event, &handler)
      @handlers[event].add(handler)
      handler
    end

    # Queues data for writing. It is not guaranteed that client will receive message.
    #
    # @param [#to_s] data
    # @param [Symbol] type
    def write(data, type: :text)
      frame = ::WebSocket::Frame::Outgoing::Server.new(data: data, type: type, version: @handshake.version)
      @stream.write(frame.to_s)
    end

    # Close the connection.
    #
    # Can safely be called multiple times.
    def close
      @stream.close if @stream
    end

    private

    # Trigger all handlers for the given event with the given arguments.
    #
    # @param [Symbol] event
    def trigger(event, *args)
      @handlers[event].each { |handler| handler.call(*args) }
    end

    # Main loop of the WebSocket thread.
    def hijack
      unless @env["rack.hijack?"]
        raise HijackingNotSupported, "server does not support hijacking"
      end

      # See http://www.rubydoc.info/github/rack/rack/file/SPEC
      @env["rack.hijack"].call
      @io = @env["rack.hijack_io"]

      yield

      @handshake.from_rack(@env)
      raise @handshake.error unless @handshake.valid?

      frame_parser = ::WebSocket::Frame::Incoming::Server.new(version: @handshake.version)
      @stream = Livereload::Stream.new(@io) do |input|
        handle_frames(frame_parser, input)
      end
      @stream.write(@handshake.to_s)

      trigger :open
      handle_frames(frame_parser, @handshake.leftovers)

      @stream.loop
    ensure
      close
      trigger :close, *$!
    end

    def handle_frames(frame_parser, data)
      frame_parser << data

      while frame = frame_parser.next
        case frame.type
        when :text, :binary
          trigger :message, frame
        when :ping
          write(nil, :pong)
        when :pong
          # TODO: reset timeout timer.
        when :close
          close
        else
          raise "unknown frame type #{frame.type}"
        end
      end
    end
  end
end
