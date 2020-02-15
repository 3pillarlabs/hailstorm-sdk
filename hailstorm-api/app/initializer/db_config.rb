require 'erb'
require 'yaml'
require 'active_record/base'
require 'active_record/errors'

require 'hailstorm/behavior/loggable'

class DbConfig
  include Hailstorm::Behavior::Loggable

  def self.initialize
    ActiveRecord::Base.logger = logger
    database_properties = YAML.load_file(File.expand_path('../../../config/database.yml', __FILE__))
    database_properties.symbolize_keys!
    connection_spec = eval(ERB.new(database_properties[Hailstorm.env].to_s).result)
    connection_spec.symbolize_keys!
    connection_spec.merge!(pool: 50, wait_timeout: 30.minutes)
    ActiveRecord::Base.establish_connection(connection_spec)
    create_database_if_not_exists(connection_spec)
    at_exit { ActiveRecord::Base.connection.disconnect! if ActiveRecord::Base.connected? }
  end

  def self.create_database_if_not_exists(connection_spec)
    test_connection!
  rescue ActiveRecord::ActiveRecordError
    logger.info 'Database does not exist, creating...'
    create_database(connection_spec)
  end

  def self.test_connection!
    ActiveRecord::Base.connection.exec_query('select 1')
  end

  def self.create_database(connection_spec)
    ActiveRecord::Base.establish_connection(connection_spec.merge(database: nil))
    ActiveRecord::Base.connection.create_database(connection_spec[:database])
    ActiveRecord::Base.establish_connection(connection_spec)
  end
end

DbConfig.initialize
