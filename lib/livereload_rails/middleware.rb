require "monitor"
require "set"
require "filewatcher"

module LivereloadRails
  class Middleware
    ASYNC_RESPONSE = [-1, {}, []]

    def initialize(app, assets: , matchers: LivereloadRails.matchers)
      @app = app
      @clients = Set.new
      @clients.extend(MonitorMixin)

      assets.configure do |environment|
        @watcher = Watcher.new(environment.paths) do |path, event|
          if filename = matchers.translate(path)
            client_path = "#{assets.prefix}/#{filename}"

            clients = @clients.synchronize { @clients.dup }
            clients.each { |client| client.reload(client_path) }

            LivereloadRails.logger.debug "#{path} -> #{filename}: #{@clients.count} clients updated."
          else
            LivereloadRails.logger.debug "#{path} -> no match."
          end
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
            LivereloadRails.logger.debug "#{client} joined."
            @clients.synchronize { @clients.add(client) }
          end

          ws.on(:close) do
            LivereloadRails.logger.debug "#{client} left."
            @clients.synchronize { @clients.delete(client) }
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
