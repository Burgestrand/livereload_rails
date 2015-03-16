require "tubesock"

module Livereload
  class Client
    FSM = {
      opened: { "hello" => :on_hello },
      idle:   { "info" => nil },
      closed: {},
    }

    class << self
      def listen(env, &block)
        client = new(env, &block)
        client.listen
        client
      end
    end

    def initialize(env)
      @state = :initial

      @connection = Tubesock.hijack(env)
      @connection.onopen do
        yield self, :open
        @state = :opened
      end

      @connection.onclose do
        if close and block_given?
          yield self, :close
        end
      end

      @connection.onmessage do |data|
        begin
          data = JSON.parse(data)
          command = data["command"]

          if FSM[@state].has_key?(command)
            if handler = FSM[@state][command]
              public_send(handler, data)
            end
          else
            close "Unexpected #{data["command"].inspect} in #{@state}."
          end
        rescue => error
          # See: https://github.com/ngauthier/tubesock/issues/44
          close error.inspect
          raise
        end
      end
    end

    def listen
      @listen_thread = @connection.listen
    end

    def on_hello(frame)
      send_data({
        command: "hello",
        protocols: [
          "http://livereload.com/protocols/official-7"
        ],
        serverName: "Elabs' Livereload",
      })

      @state = :idle
    end

    def reload(path, live: true)
      send_data(command: "reload", path: path, liveCSS: live)
    end

    def alert(message)
      send_data(command: "alert", message: message)
    end

    def close(reason = nil)
      if @state != :closed
        @state = :closed
        alert(reason) if reason
        @connection.close
        true
      else
        false
      end
    end

    private

    def send_data(object)
      @connection.send_data JSON.generate(object)
    end
  end
end
