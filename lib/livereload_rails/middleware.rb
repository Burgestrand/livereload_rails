require "monitor"
require "set"
require "filewatcher"

module LivereloadRails
  class Middleware
    ASYNC_RESPONSE = [-1, {}, []]

    def initialize(app, assets:, matchers: LivereloadRails.matchers)
      @app = app
      @clients = Set.new
      @clients.extend(MonitorMixin)

      assets.configure do |environment|
        @watcher = Watcher.new(environment.paths, matchers: matchers) do |file|
          client_path = "#{assets.prefix}/#{file}"
          clients = @clients.synchronize { @clients.dup }

          LivereloadRails.logger.debug "Reloading #{clients.size} clients with #{client_path}."
          clients.each { |client| client.reload(client_path) }
        end

        @watcher_thread = Thread.new do
          Thread.current.abort_on_exception = true
          @watcher.run
        end
      end
    end

    def call(env)
      if env["PATH_INFO"] == "/livereload"
        websocket = LivereloadRails::WebSocket.from_rack(env) do |ws|
          client = LivereloadRails::Client.new(ws)

          ws.on(:open) do
            @clients.synchronize { @clients.add(client) }
            LivereloadRails.logger.debug "#{client} joined: #{@clients.size}."
          end

          ws.on(:close) do
            @clients.synchronize { @clients.delete(client) }
            LivereloadRails.logger.debug "#{client} left: #{@clients.size}."
          end
        end

        if websocket
          ASYNC_RESPONSE
        else
          @app.call(env)
        end
      else
        @app.call(env)
      end
    end
  end
end
