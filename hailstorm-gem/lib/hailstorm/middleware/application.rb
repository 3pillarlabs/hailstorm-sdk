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
      Hailstorm.application.load_config(true)
    end
    Hailstorm.application.connection_spec = connection_spec
    Hailstorm.application.check_database

    Hailstorm.application
  end

  attr_writer :multi_threaded

  attr_writer :logger

  attr_accessor :command_interpreter

  # Constructor
  def initialize
    @multi_threaded = true
  end

  def multi_threaded?
    @multi_threaded
  end

  def config=(new_config)
    @config = new_config
    self
  end

  def config(&_block)
    @config ||= Hailstorm::Support::Configuration.new
    if block_given?
      yield @config
    else
      @config
    end
  end

  def load_config(handle_load_error = false)
    @config = nil
    load(File.join(Hailstorm.root, Hailstorm.config_dir, 'environment.rb'))
    @config.freeze
  rescue Object => e
    handle_load_error ? logger.fatal(e.message) : raise(Hailstorm::Exception, e.message)
  end
  alias reload load_config

  def check_database
    fail_once = false
    begin
      ActiveRecord::Base.establish_connection(connection_spec) # this is lazy, does not fail!
      # create/update the schema
      Hailstorm::Support::Schema.create_schema
    rescue ActiveRecord::ActiveRecordError => e
      if !fail_once
        fail_once = true
        logger.info 'Database does not exist, creating...'
        # database does not exist yet
        create_database
        retry
      else
        logger.error e.message
        raise
      end
    ensure
      ActiveRecord::Base.clear_all_connections!
    end
  end

  # Writer for @connection_spec
  # @param [Hash] spec
  def connection_spec=(spec)
    @connection_spec = spec.symbolize_keys if spec
  end

  private

  def database_name
    Hailstorm.app_name
  end

  def create_database
    ActiveRecord::Base.establish_connection(connection_spec.merge(database: nil))
    ActiveRecord::Base.connection.create_database(connection_spec[:database])
    ActiveRecord::Base.establish_connection(connection_spec)
  end

  def connection_spec
    if @connection_spec.nil?
      @connection_spec = {}

      # load the properties into a java.util.Properties instance
      database_properties_file = Java::JavaIo::File.new(File.join(Hailstorm.root,
                                                                  Hailstorm.config_dir,
                                                                  'database.properties'))
      properties = Java::JavaUtil::Properties.new
      properties.load(Java::JavaIo::FileInputStream.new(database_properties_file))

      # load all properties without an empty value into the spec
      properties.each do |key, value|
        @connection_spec[key.to_sym] = value unless value.blank?
      end

      # switch off multithread mode for sqlite & derby
      if @connection_spec[:adapter] =~ /(?:sqlite|derby)/i
        @multi_threaded = false
        @connection_spec[:database] = File.join(Hailstorm.root, Hailstorm.db_dir,
                                                "#{database_name}.db")
      else
        # set defaults which can be overridden
        @connection_spec = {
            pool: 50,
            wait_timeout: 30.minutes
        }.merge(@connection_spec).merge(database: database_name)
      end
    end

    @connection_spec
  end

end
