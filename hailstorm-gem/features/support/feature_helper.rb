require 'bundler/setup'

$LOAD_PATH.push(File.expand_path('../../lib', __FILE__))
BUILD_PATH = File.join(File.expand_path('../../..', __FILE__), 'build').freeze
FileUtils.rm_rf(BUILD_PATH)
FileUtils.mkdir_p(BUILD_PATH)

$CLASSPATH << File.expand_path('../../data', __FILE__)
require 'hailstorm/initializer/java_classpath'
require 'hailstorm/initializer/eager_load'
require 'hailstorm/support/configuration'
require 'hailstorm/support/schema'
require 'active_record/base'
require 'hailstorm/support/log4j_backed_logger'

ENV['HAILSTORM_ENV'] = 'cucumber'

connection_spec = {
  adapter: 'jdbcmysql',
  database: "hailstorm_#{ENV['HAILSTORM_ENV']}",
  username: 'hailstorm_dev',
  password: 'hailstorm_dev'
}

ActiveRecord::Base.logger = Hailstorm::Support::Log4jBackedLogger.get_logger(ActiveRecord::Base)
ActiveRecord::Base.establish_connection(connection_spec)
ActiveRecord::Base.connection.drop_database(connection_spec[:database]) rescue false
ActiveRecord::Base.establish_connection(connection_spec.except(:database))
ActiveRecord::Base.connection.create_database(connection_spec[:database])
ActiveRecord::Base.establish_connection(connection_spec)

Hailstorm::Support::Schema.create_schema

def data_path
  @data_path ||= File.expand_path('../../data', __FILE__)
end

Dir['lib/*.rb'].each { |helper| load(helper) }
