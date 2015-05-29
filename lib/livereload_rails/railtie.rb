require "livereload_rails"
require "rails/engine"
require "rack-livereload"

module LivereloadRails
  class Railtie < ::Rails::Engine
    config.app_middleware.use Rack::LiveReload, live_reload_port: Rails::Server.new.options[:Port]
    config.app_middleware.use LivereloadRails::Middleware, assets: config.assets
  end
end
