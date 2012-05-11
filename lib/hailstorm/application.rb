# All calls from the rake task are routed to this appropriate methods. This
# class acts as a "Controller" for the application.
# @author Sayantam Dey

require 'hailstorm'
require 'hailstorm/exceptions'
require 'hailstorm/support/configuration'
require 'hailstorm/support/command_processor'
require 'hailstorm/support/schema'
require 'hailstorm/support/thread'
require 'hailstorm/model/project'

require 'hailstorm/model/nmon'

class Hailstorm::Application
  

  # Initialize the application and connects to the database
  # @param [String] app_name the application name
  # @param [String] boot_file_path full path to application config/boot.rb
  # @return nil
  def self.initialize!(app_name, boot_file_path)
    
    Hailstorm.app_name = app_name
    Hailstorm.root = File.expand_path("../..", boot_file_path)
    Hailstorm.application = self.new
    Hailstorm.application.load_config()
    Hailstorm.application.mutex = Mutex.new()
    Hailstorm.application.connect_to_database()
  end
  
  # Processes the user commands and options
  def self.process_commands
    # relay to application instance
    Hailstorm.application.command_processor.execute()
  end

  ## Exposed Hailstorm::Configuration instance
  #@@config = nil
  #def self.config
  #  @@config ||= Hailstorm::Support::Configuration.new
  #end
  
  attr_reader :command_processor
  
  attr_accessor :mutex
  
  def initialize
    #@config = self.class.config
    #@config.compute_serial_version()
    #@config.freeze()
    @command_processor = Hailstorm::Support::CommandProcessor.new()
  end

  def config(&block)

    @config ||= Hailstorm::Support::Configuration.new
    if block_given?
      yield @config
    else
      return @config
    end
  end

  def connect_to_database()

    # Setup connection to the database
    # unless database_exists?
      # FileUtils.touch(database_name())
    # end
    ActiveRecord::Base.logger = logger
    
    ActiveRecord::Base.establish_connection(connection_spec)
    
  end
  
  # Initializes the application - creates directory structure and database
  def init()
    # TODO:
  end
  
  # Sets up the load agents and targets. 
  # Creates the load agents as needed and pushes the Jmeter scripts to the agents.
  # Pushes the monitoring artifacts to targets.
  # @note Currently a single cloud is supported, will not work across clouds in
  # different geo zones.
  def setup()

    # create/update the schema
    Hailstorm::Support::Schema.create_schema()

    # sqlite3_db_synchronization_patches()
    
    # load/reload the configuration
    current_project.setup()
  end
  
  # Starts the load generation and monitoring on targets
  def start()
    
    execute do
      logger.info("Starting load generation and monitoring on targets...")
      current_project.start()
    end
  end
  
  # Stops the load generation and monitoring on targets and collects all logs
  def stop()
    
    execute do
      logger.info("Stopping load generation and monitoring on targets...")
      current_project.stop()
    end
  end
  
  def abort()
    
    execute do
      logger.info("Aborting load generation and monitoring on targets...")
      current_project.abort()
    end
  end
  
  def terminate()
    
    execute do
      logger.info("Terminating test cycle...")
      current_project.terminate()
    end    
  end

  def report()

    execute do
      current_project.generate_report()
    end
  end

  def load_config()
    @config = nil
    load(File.join(Hailstorm.root, Hailstorm.config_dir, 'environment.rb'))
    @config.freeze()
  end
  alias :reload :load_config

  def purge()
    current_project.destroy()
    @current_project = nil
  end

  def show()
    current_project.show()
  end

########################## PRIVATE METHODS ##################################
  private
  
  # single point for executing all commands, for exception handling.
  def execute(&block)
    
    begin
      yield
    rescue Object => e
      logger.error(e.message)
      logger.debug { "\n".concat(e.backtrace().join("\n")) }
      # TODO: Take different action based on the type of exception
    end
  end
  
  def current_project
    @current_project ||= Hailstorm::Model::Project
        .where(:project_code => Hailstorm.app_name)
        .first_or_create!()
  end
  
  def database_exists?
    
    # FIXME    
    # File.exists?(database_name())
  end
  
  def database_name()
    # @database_name ||= File.join(Hailstorm.root, Hailstorm.db_dir, 
                                              # "#{Hailstorm.app_name}.sqlite3")
    Hailstorm.app_name 
  end

  def create_database()
    # FIXME
    # FileUtils.touch(database_name())
  end

  def connection_spec
    @connection_spec ||= {
      :adapter => "jdbc",
      :driver => "com.mysql.jdbc.Driver",
      :url => "jdbc:mysql://localhost:3306/#{database_name}",
      :username => 'hailstorm',
      :password => 'hailstorm',
      :pool => 10
    }
  end

  def sqlite3_db_synchronization_patches()
    ActiveRecord::Base.connection.class.class_eval do

      alias :real_execute :execute
      def execute(*args)
        
        Hailstorm.logger.debug { "#{self.class}##{__method__}^#{Hailstorm.application.mutex.object_id}" }
        num_tries = 0
        if Thread.list.size > 1
          Hailstorm.application.mutex.lock()
          Hailstorm.logger.debug { "ACQUIRED LOCK..." }
        end
        begin
          real_execute(*args) 
        rescue Exception => e
          Hailstorm.logger.error { "#{e.class}: #{e.message}" }
          if e.message =~ /SQLITE_BUSY/
            logger.debug { "SQLITE_BUSY #{num_tries} times, trying again..." }
            # num_tries < 12 ? (num_tries += 1; sleep(10); retry) : raise
            num_tries < 12 ? (num_tries += 1; Thread.pass; retry) : raise
          else
            raise
          end
        end
      end
      
      def select(*args)
        real_execute(*args)
      end
      
      alias :real_commit_db_transaction :commit_db_transaction
      def commit_db_transaction(*args)
        
        Hailstorm.logger.debug { "#{self.class}##{__method__}^#{Hailstorm.application.mutex.object_id}" }
        begin
          retval = real_commit_db_transaction(*args)
          if Thread.list.size > 1
            Hailstorm.application.mutex.tap do |mtx|
              if mtx.locked?
                mtx.unlock()
                Hailstorm.logger.debug { "RELEASED LOCK..." }
              end
            end
          end
          return retval
        rescue Exception => e
          Hailstorm.logger.error { "#{e.class}: #{e.message}" }
          if e.message =~ /SQLITE_BUSY/
            logger.debug { "SQLITE_BUSY #{num_tries} times, trying again..." }
            # num_tries < 12 ? (num_tries += 1; sleep(10); retry) : raise
            num_tries < 12 ? (num_tries += 1; Thread.pass; retry) : raise
          else
            raise
          end
        end
      end
      
      alias :real_rollback_db_transaction :rollback_db_transaction
      def rollback_db_transaction(*args)
        
        Hailstorm.logger.debug { "#{self.class}##{__method__}^#{Hailstorm.application.mutex.object_id}" }
        begin
          real_rollback_db_transaction(*args)
        rescue Exception => e
          if e.message =~ /SQLITE_BUSY/
            logger.debug { "SQLITE_BUSY #{num_tries} times, trying again..." }
            # num_tries < 12 ? (num_tries += 1; sleep(10); retry) : raise
            num_tries < 12 ? (num_tries += 1; Thread.pass; retry) : raise
          else
            raise
          end
        ensure
          if Thread.list.size > 1
            Hailstorm.application.mutex.unlock()
            Hailstorm.logger.debug { "RELEASED LOCK (ROLLBACK)..." }
          end
        end
      end
    end
    
  end
  

end
