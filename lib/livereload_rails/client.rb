module LivereloadRails
  class Client
    FSM = {
      initial: {},
      opened: { "hello" => :on_hello },
      idle:   { "info" => nil },
      closed: {},
    }

    def initialize(ws)
      @state = :initial

      @connection = ws
      @connection.on(:open) { @state = :opened }
      @connection.on(:close) { close }
      @connection.on(:message) do |frame|
        data = JSON.parse(frame.data)
        command = data["command"]

        if FSM[@state].has_key?(command)
          if handler = FSM[@state][command]
            public_send(handler, data)
          end
        else
          raise "Unexpected #{data["command"].inspect} in #{@state}."
        end
      end
    end

    def on_hello(frame)
      send_data({
        command: "hello",
        protocols: [
          "http://livereload.com/protocols/official-7"
        ],
        serverName: "Elabs' LivereloadRails",
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
      @connection.write JSON.generate(object)
    end
  end
end
