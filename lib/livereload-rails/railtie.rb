module Livereload
  class Railtie < ::Rails::Railtie
    config.app_middleware.use Livereload::Middleware, assets: config.assets
  end
end
