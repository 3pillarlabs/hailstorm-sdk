require 'hailstorm/initializer/eager_load'
require 'initializer/log_config'
require 'initializer/redis_logger'
require 'hailstorm/support/log4j_backed_logger'
require 'initializer/logger_redis_ext' unless Hailstorm.env == :test
require 'hailstorm/initializer/java_classpath'
require 'initializer/db_config'
require 'initializer/migrations'
require 'web_file_store'
require 'version'

Hailstorm.fs = WebFileStore.new

require 'sinatra'

helpers do
  def logger
    Hailstorm::Support::Log4jBackedLogger.get_logger(self.class)
  end
end

before do
  response.headers['Access-Control-Allow-Origin'] = '*'
end

after do
  content_type :json
end

options '*' do
  response.headers['Access-Control-Allow-Origin'] = '*'
  response.headers['Access-Control-Allow-Methods'] = 'GET, PUT, POST, DELETE, PATCH, OPTIONS'
  response.headers['Access-Control-Allow-Headers'] = 'Content-Type, Accept'
  200
end

get '/' do
  JSON.dump(paths: %w[/projects /execution_cycles], version: Hailstorm::Api::VERSION)
end

require 'helpers/api_helper'
helpers ApiHelper

set :show_exceptions, :after_handler

require 'active_record/errors'
error ActiveRecord::RecordNotFound do
  not_found
end

require 'hailstorm/exceptions'

# @param [StandardError] error
def log_error_backtrace(error)
  logger.error(error.message)
  logger.error(error.backtrace.join("\n"))
end

error StandardError do
  bubbled_error = env['sinatra.error']
  log_error_backtrace(bubbled_error)
  if bubbled_error.is_a?(Hailstorm::ThreadJoinException)
    bubbled_error.exceptions.each { |inner_error| log_error_backtrace(inner_error) }
  end

  500
end
