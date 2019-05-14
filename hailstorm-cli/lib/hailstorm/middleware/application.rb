require 'active_record/base'
require 'active_record/errors'

require 'hailstorm/middleware'
require 'hailstorm/exceptions'
require 'hailstorm/behavior/loggable'
require 'hailstorm/support/configuration'
require 'hailstorm/support/schema'

# Application Middleware
class Hailstorm::Middleware::Application

  include Hailstorm::Behavior::Loggable

  # # Initialize the application and connects to the database
  # # @param [Hash] connection_spec map of properties for the database connection
  # # @param [Hailstorm::Support::Configuration] env_config config object
  # # @return [Hailstorm::Middleware::Application] initialized application middleware
  def self.initialize(connection_spec = nil, env_config = nil)
    ActiveRecord::Base.logger = logger
    Hailstorm.application = new
    if env_config
      Hailstorm.application.config = env_config
    else
      Hailstorm.application.load_config
    end
    Hailstorm.application.connection_spec = connection_spec
    Hailstorm.application.check_database

    Hailstorm.application
  end

  attr_writer :logger

  attr_accessor :command_interpreter

  attr_writer :config

  def config(&_block)
    @config ||= Hailstorm::Support::Configuration.new
    yield @config if block_given?
    @config
  end

  def load_config(environment_file = File.join(Hailstorm.root, Hailstorm.config_dir, 'environment.rb'))
    @config = nil
    load(environment_file)
    @config.freeze
  rescue Object => e
    logger.fatal(e.message)
    raise(Hailstorm::Exception, e.message)
  end
  alias reload load_config

  def check_database
    ActiveRecord::Base.establish_connection(connection_spec) # this is lazy, does not fail!
    create_database_if_not_exists
    # create/update the schema
    Hailstorm::Support::Schema.create_schema
  ensure
    ActiveRecord::Base.clear_all_connections!
  end

  # Writer for @connection_spec
  # @param [Hash] spec
  def connection_spec=(spec)
    @connection_spec = spec.symbolize_keys if spec
  end

  # Computes the SHA2 hash of the environment file and contents/structure of JMeter
  # directory.
  # @return [String]
  def config_serial_version
    digest = Digest::SHA2.new

    Dir[File.join(Hailstorm.root, Hailstorm.app_dir, '**', '*.jmx')].sort.each do |file|
      digest.update(file)
    end

    File.open(Hailstorm.environment_file_path, 'r') do |ef|
      ef.each_line do |line|
        digest.update(line)
      end
    end

    digest.hexdigest
  end

  private

  def database_name
    @database_name ||= Hailstorm.is_production? ? 'hailstorm_production' : 'hailstorm_development'
  end

  def create_database_if_not_exists
    ActiveRecord::Base.connection.exec_query('select 1')
  rescue ActiveRecord::ActiveRecordError
    logger.info 'Database does not exist, creating...'
    create_database
  end

  def create_database
    ActiveRecord::Base.establish_connection(connection_spec.merge(database: nil))
    ActiveRecord::Base.connection.create_database(connection_spec[:database])
    ActiveRecord::Base.establish_connection(connection_spec)
  end

  def connection_spec
    return @connection_spec if @connection_spec

    # set defaults which can be overridden, and load and filter keys without an empty value
    @connection_spec = {
      pool: 50,
      wait_timeout: 30.minutes
    }.merge(load_db_properties.reject { |_k, v| v.blank? })

    @connection_spec[:database] ||= database_name

    @connection_spec
  end

  # load the properties into a java.util.Properties instance
  def load_db_properties(db_props_file_path = File.join(Hailstorm.root, Hailstorm.config_dir, 'database.properties'))
    database_properties_file = Java::JavaIo::File.new(db_props_file_path)
    properties = Java::JavaUtil::Properties.new
    properties.load(Java::JavaIo::FileInputStream.new(database_properties_file))

    # return all properties
    properties.to_hash.symbolize_keys
  end

end
