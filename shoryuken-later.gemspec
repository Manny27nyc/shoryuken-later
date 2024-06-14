# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "shoryuken/later/version"

Gem::Specification.new do |spec|
  spec.name        = "shoryuken-later"
  spec.version     = Shoryuken::Later::VERSION
  spec.authors     = ["Joe Khoobyar"]
  spec.email       = ["joe@khoobyar.name"]
  spec.homepage    = "http://github.com/joekhoobyar/shoryuken-later"
  spec.summary     = 'A scheduling plugin (using Dynamo DB) for Shoryuken'
  spec.description = %{
    This gem provides a scheduling plugin (using Dynamo DB) for Shoryuken, as well as an ActiveJob adapter
  }

  spec.license = "LGPL-3.0"
  spec.files = `git ls-files -z`.split("\x0")
  spec.executables = %w[shoryuken-later]
  spec.test_files = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.required_ruby_version = '>= 2.5.0'

  spec.add_development_dependency "bundler", '>= 1.3.5'
  spec.add_development_dependency "pry-byebug"
  spec.add_development_dependency "rake", '~> 13.2'
  spec.add_development_dependency "rspec", '~> 3.0', '< 3.1'

  spec.add_dependency "aws-sdk-dynamodb", "~> 1.32.0"
  spec.add_dependency "aws-sdk-sqs", ">= 1.17.0"
  spec.add_dependency "shoryuken", ">= 4.0.0"
  spec.add_dependency "timers", "~> 4.1.0"
end
