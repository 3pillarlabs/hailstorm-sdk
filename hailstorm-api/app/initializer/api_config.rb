require 'hailstorm/initializer/eager_load'
require 'initializer/log_config'
require 'hailstorm/initializer/java_classpath'
require 'initializer/db_config'
require 'initializer/migrations'
require 'hailstorm/support/log4j_backed_logger'
require 'web_file_store'

Hailstorm.fs = WebFileStore.new

require 'sinatra'

helpers do
  def logger
    Hailstorm::Support::Log4jBackedLogger.get_logger(self.class)
  end
end

before do
  response.headers['Access-Control-Allow-Origin'] = "*"
end

after do
  content_type :json
end

options "*" do
  response.headers["Access-Control-Allow-Origin"] = "*"
  response.headers["Access-Control-Allow-Methods"] = "GET, PUT, POST, DELETE, PATCH, OPTIONS"
  response.headers["Access-Control-Allow-Headers"] = "Content-Type, Accept"
  200
end

get "/" do
  JSON.dump(%W[/projects /execution_cycles])
end

require 'helpers/api_helper'
helpers ApiHelper

set :show_exceptions, :after_handler
require 'active_record/errors'
error ActiveRecord::RecordNotFound do
  not_found
end
