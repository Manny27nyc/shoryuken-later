# frozen_string_literal: true

require 'bundler/setup'
Bundler.setup

if ENV['CODECLIMATE_REPO_TOKEN']
  require 'codeclimate-test-reporter'
  CodeClimate::TestReporter.start
end

require 'shoryuken-later'
require 'json'

options_file = File.join(File.expand_path('..', __dir__), 'shoryuken.yml')

$options = {}

if File.exist? options_file
  $options = YAML.safe_load(File.read(options_file)).deep_symbolize_keys

  Aws.config = $options[:aws]
end

Shoryuken.logger.level = Logger::UNKNOWN

# For Ruby 1.9
module Kernel
  unless method_defined? :Hash
    def Hash(arg)
      case arg
      when NilClass
        {}
      when Hash
        arg
      when Array
        Hash[*arg]
      else
        raise TypeError
      end
    end
  end
end

# For Ruby 1.9
class Hash
  unless method_defined? :to_h
    def to_h
      self
    end
  end
end

class TestWorker
  include Shoryuken::Worker

  shoryuken_options queue: 'shoryuken_later', schedule_table: 'shoryuken_later'

  def perform(sqs_msg, body); end
end

RSpec.configure do |config|
  config.before do
    Shoryuken::Later::Client.class_variable_set :@@tables, {}

    Shoryuken::Later.options.clear
    Shoryuken::Later.options.merge!($options)

    Shoryuken::Later.tables.replace(['shoryuken_later'])

    Shoryuken::Later.options[:later] = {}
    Shoryuken::Later.options[:later][:delay] = 60
    Shoryuken::Later.options[:later][:tables] = ['shoryuken_later']
    Shoryuken::Later.options[:timeout] = 1

    Shoryuken::Later.options[:aws] = {}

    TestWorker.get_shoryuken_options.clear
    TestWorker.get_shoryuken_options['queue'] = 'shoryuken_later'
    TestWorker.get_shoryuken_options['schedule_table'] = 'shoryuken_later'

    Shoryuken.worker_registry.clear
    Shoryuken.register_worker('shoryuken_later', TestWorker)
  end
end
