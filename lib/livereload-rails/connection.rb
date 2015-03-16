module Livereload
  class Connection
    FSM = {
      opened: { "hello" => :on_hello },
      idle:   { "info" => nil },
      closed: {},
    }

    class << self
      def to_proc
        method(:new).to_proc
      end
    end

    def initialize(connection)
      @state = :initial

      @connection = connection
      @connection.onopen { @state = :opened }
      @connection.onclose { close }

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

    def files_changed(asset, event)
      send_reload(asset.digest_path)
    end

    def on_hello(frame)
      @state = :idle
      send_data({
        command: "hello",
        protocols: [
          "http://livereload.com/protocols/official-7"
        ],
        serverName: "Elabs' Livereload",
      })
    end

    def send_url(url)
      send_data(command: "url", url: url)
    end

    def send_reload(path, live: true)
      send_data(command: "reload", path: path, liveCSS: live)
    end

    def send_alert(message)
      send_data(command: "alert", message: message)
    end

    def close(reason = nil)
      unless @state == :closed
        @state = :closed
        send_alert(reason) if reason
        @connection.close
      end
    end

    private

    def send_data(object)
      @connection.send_data JSON.generate(object)
    end
  end
end
