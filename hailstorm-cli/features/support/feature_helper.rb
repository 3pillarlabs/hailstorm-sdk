require 'bundler/setup'
require 'active_support/all'

BUILD_PATH = File.join(File.expand_path('../../..', __FILE__), 'build', 'integration').freeze
FileUtils.rm_rf(BUILD_PATH)
FileUtils.mkdir_p(BUILD_PATH)

ENV['HAILSTORM_ENV'] = 'cli_integration' unless ENV['HAILSTORM_ENV']

require 'active_record'
require 'active_record/base'
require 'active_record/errors'

connection_spec = {
  adapter:  'jdbcmysql',
  database: "hailstorm_#{ENV['HAILSTORM_ENV']}",
  username: 'hailstorm_dev',
  password: 'hailstorm_dev',
  host: ENV['DATABASE_HOST'] || 'localhost'
}

ActiveRecord::Base.establish_connection(connection_spec)
begin
  ActiveRecord::Base.connection.drop_database(connection_spec[:database])
rescue ActiveRecord::ActiveRecordError
  puts "Database #{connection_spec[:database]} does not exist, creating..."
ensure
  ActiveRecord::Base.establish_connection(connection_spec.merge(database: nil))
  ActiveRecord::Base.connection.create_database(connection_spec[:database])
  ActiveRecord::Base.connection.disconnect!
end

def build_path
  BUILD_PATH
end
