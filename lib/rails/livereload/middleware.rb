module Livereload
  class Middleware
    def initialize(app, assets: , port: Rails::Server.new.options[:Port])
      @app = app
      @port = port

      assets.configure do |environment|
        @environment = environment
      end
    end

    def call(env)
      binding.pry

      case env["PATH_INFO"]
      when "/livereload"
        if env["HTTP_UPGRADE"] == "websocket"
          livereload(env)
        else
          @app.call(env)
        end
      else
        @app.call(env)
      end
    end

    def livereload(env)
      connection = Livereload::Client.new(env)
      [-1, {}, []]
    end
  end
end
