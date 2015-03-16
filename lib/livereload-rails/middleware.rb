require "monitor"
require "weak_observable"
require "filewatcher"

module Livereload
  class Middleware
    def initialize(app, assets: )
      @app = app
      @clients = WeakObservable.new

      assets.configure do |environment|
        @watcher = Watcher.new(environment.paths) do |path, event|
          asset = environment.find_asset(path, bundle: false)
          @clients.notify("#{assets.prefix}/#{asset.digest_path}")
        end

        @watcher_thread = Thread.new do
          Thread.current.abort_on_exception = true
          @watcher.run
        end
      end
    end

    def call(env)
      if env["HTTP_UPGRADE"] == "websocket" && env["PATH_INFO"] == "/livereload"
        livereload(env)
      else
        @app.call(env)
      end
    end

    def livereload(env)
      Livereload::Client.listen(env) do |client, event|
        puts "Client event: #{event}"

        case event
        when :open
          @clients.add(client, :reload)
        when :close
          @clients.delete(client)
        end
      end

      [-1, {}, []]
    end
  end
end
