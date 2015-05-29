require "livereload_rails/version"
require "livereload_rails/watcher"
require "livereload_rails/stream"
require "livereload_rails/web_socket"
require "livereload_rails/client"
require "livereload_rails/middleware"
require "livereload_rails/railtie" if defined?(Rails)

module LivereloadRails
  class Error < StandardError; end
  class HijackingNotSupported < Error; end
end
