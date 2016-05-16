require "livereload_rails"
require "rails/engine"
require "rails/commands/server"
require "rack-livereload"

module LivereloadRails
  class Railtie < ::Rails::Engine
    config.app_middleware.insert_before "Rack::Lock", LivereloadRails::Middleware, assets: config.assets
    config.app_middleware.use Rack::LiveReload, live_reload_port: ::Rails::Server.new.options[:Port]
  end
end
