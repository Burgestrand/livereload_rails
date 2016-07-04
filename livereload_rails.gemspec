# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'livereload_rails/version'

Gem::Specification.new do |spec|
  spec.name          = "livereload_rails"
  spec.version       = LivereloadRails::VERSION
  spec.authors       = ["Kim Burgestrand", "Elabs"]
  spec.email         = ["kim@burgestrand.se", "dev@elabs.se"]

  spec.summary       = %q{Easy livereloading of assets for Rails.}
  spec.homepage      = "https://github.com/Burgestrand/livereload_rails"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "filewatcher", ">= 0"
  spec.add_runtime_dependency "websocket", ">= 0"
  spec.add_runtime_dependency "nio4r", ">= 0"
  spec.add_runtime_dependency "puma", ">= 0"
  spec.add_runtime_dependency "rack-livereload", ">= 0"
  spec.add_runtime_dependency "railties", ">= 4"

  spec.add_development_dependency "pry"
  spec.add_development_dependency "bundler", "~> 1.8"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
