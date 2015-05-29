require "logger"
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

  @matchers = {}
  @logger = Logger.new(File::NULL)
  @paths = lambda { |paths| paths }

  class << self
    attr_accessor :matchers
    attr_accessor :logger
    attr_accessor :paths

    def configure
      yield self
    end
  end
end

LivereloadRails.configure do |config|
  config.matchers[:stylesheets] = lambda do |file|
    "everything.css" if file["assets/stylesheets/"]
  end

  config.matchers[:assets] = lambda do |file|
    "everything#{File.extname(file)}" if file["assets/"]
  end

  config.matchers[:views] = lambda do |file|
    "everything.html" if file["views/"]
  end

  config.paths = lambda do |paths|
    [File.join(Dir.pwd, "app/views")].concat(paths)
  end

  config.logger = Logger.new($stderr)
  config.logger.level = Logger::INFO
end
