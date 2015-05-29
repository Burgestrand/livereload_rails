require "monitor"
require "set"
require "filewatcher"

module LivereloadRails
  class Middleware
    ASYNC_RESPONSE = [-1, {}, []]

    def initialize(app, assets: )
      @app = app
      @clients = Set.new
      @clients.extend(MonitorMixin)

      assets.digest = false
      assets.configure do |environment|
        @watcher = Watcher.new(environment.paths) do |path, event|
          asset = environment.find_asset(path, bundle: false)
          client_path = "#{assets.prefix}/#{asset.logical_path}"
          @clients.each { |client| client.reload(client_path) }
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
          end

          ws.on(:close) do
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
