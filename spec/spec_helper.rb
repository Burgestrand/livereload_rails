require "bundler/setup"
require "livereload-rails"
require "timeout"

require "support/fake_io"

RSpec.configure do |config|
  config.around(:each, timeout: proc { |t| t }) do |example|
    Timeout.timeout(example.metadata[:timeout], &example)
  end
end
