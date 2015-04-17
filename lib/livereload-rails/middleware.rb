require "monitor"
require "set"
require "filewatcher"

module Livereload
  class Middleware
    ASYNC_RESPONSE = [-1, {}, []]

    def initialize(app, assets: )
      @app = app
      @clients = Set.new
      @clients.extend(MonitorMixin)

      assets.digest = false
      assets.configure do |environment|
        @watcher = Watcher.new(environment.paths) do |path, event|
          puts "Asset updated: #{path}"
          asset = environment.find_asset(path, bundle: false)
          client_path = "#{assets.prefix}/#{asset.logical_path}"
          puts "Logical path: #{client_path} @ #{@clients.length} clients."
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
        websocket = Livereload::WebSocket.from_rack(env) do |ws|
          client = Livereload::Client.new(ws)

          ws.on(:open) do
            puts "New client!"
            @clients.synchronize { @clients.add(client) }
          end

          ws.on(:message) do |frame|
            puts "Message: #{frame.data}"
          end

          ws.on(:close) do
            puts "Lost client!"
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
