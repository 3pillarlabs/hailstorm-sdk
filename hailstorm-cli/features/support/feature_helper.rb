require 'bundler/setup'
require 'active_support/all'
require 'cucumber/rspec/doubles'

BUILD_PATH = File.join(File.expand_path('../../../..', __FILE__), 'build').freeze
FileUtils.rm_rf(BUILD_PATH)
FileUtils.mkdir_p(BUILD_PATH)

ENV['HAILSTORM_ENV'] = 'cucumber'

