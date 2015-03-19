require "pry"

require "livereload-rails/version"
require "livereload-rails/watcher"
require "livereload-rails/stream"
require "livereload-rails/client"
require "livereload-rails/middleware"
require "livereload-rails/engine" if defined?(Rails)

module Livereload
  class Error < StandardError; end
end
