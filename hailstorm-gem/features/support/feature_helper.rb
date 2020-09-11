# frozen_string_literal: true

require 'bundler/setup'

$LOAD_PATH.push(File.expand_path('../../lib', __FILE__))
BUILD_PATH = File.join(File.expand_path('../../..', __FILE__), 'build', 'integration').freeze
FileUtils.rm_rf(BUILD_PATH)
FileUtils.mkdir_p(BUILD_PATH)

$CLASSPATH << File.expand_path('../../data', __FILE__)
require 'hailstorm/initializer/java_classpath'
require 'hailstorm/initializer/eager_load'
require 'hailstorm/support/configuration'
require 'hailstorm/support/schema'
require 'active_record/base'
require 'active_record/errors'
require 'hailstorm/support/log4j_backed_logger'
require 'hailstorm/support/db_connection'

ENV['HAILSTORM_ENV'] = 'gem_integration' unless ENV['HAILSTORM_ENV']
ENV['HAILSTORM_WORKSPACE_ROOT'] = BUILD_PATH

connection_spec = Hailstorm::Support::DbConnection.new(
  adapter: 'jdbcmysql',
  database: "hailstorm_#{ENV['HAILSTORM_ENV']}",
  username: 'hailstorm_dev',
  password: 'hailstorm_dev'
).connection_spec

ActiveRecord::Base.logger = Hailstorm::Support::Log4jBackedLogger.get_logger(ActiveRecord::Base)
ActiveRecord::Base.establish_connection(connection_spec)
begin
  ActiveRecord::Base.connection.drop_database(connection_spec[:database])
rescue ActiveRecord::ActiveRecordError
  puts "Database #{connection_spec[:database]} does not exist, creating..."
ensure
  ActiveRecord::Base.establish_connection(connection_spec.merge(database: nil))
  ActiveRecord::Base.connection.create_database(connection_spec[:database])
  ActiveRecord::Base.establish_connection(connection_spec)
  Hailstorm::Support::Schema.create_schema
end

at_exit do
  ActiveRecord::Base.connection.disconnect!
end

def data_path
  @data_path ||= File.expand_path('../../data', __FILE__)
end

def tmp_path
  @tmp_path ||= BUILD_PATH
end
