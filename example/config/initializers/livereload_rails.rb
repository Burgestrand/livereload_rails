if defined?(LivereloadRails)
  LivereloadRails.configure do |config|
    config.logger.level = Logger::DEBUG
  end
end
