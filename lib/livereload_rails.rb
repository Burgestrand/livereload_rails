require "logger"
require "livereload_rails/version"
require "livereload_rails/matchers"
require "livereload_rails/watcher"
require "livereload_rails/stream"
require "livereload_rails/web_socket"
require "livereload_rails/client"
require "livereload_rails/middleware"
require "livereload_rails/railtie" if defined?(Rails)

module LivereloadRails
  class Error < StandardError; end
  class HijackingNotSupported < Error; end

  @matchers = Matchers.new
  @logger = Logger.new($stderr)

  class << self
    attr_reader :matchers
    attr_reader :logger

    def configure
      yield self
    end
  end
end

LivereloadRails.configure do |config|
  config.matchers.append :css do |file|
    "everything.css" if file["stylesheets"]
  end

  config.matchers.append :js do |file|
    "everything.js" if file["javascripts"]
  end

  config.logger.level = Logger::INFO
end
