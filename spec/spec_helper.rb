require "bundler/setup"
require "livereload_rails"
require "timeout"

require "support/fake_io"
require "support/helpers"

RSpec.configure do |config|
  config.around(:each, timeout: proc { |t| t }) do |example|
    Timeout.timeout(example.metadata[:timeout], &example)
  end

  config.include(Helpers)
end
