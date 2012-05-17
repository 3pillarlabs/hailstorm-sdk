# All calls from the rake task are routed to this appropriate methods. This
# class acts as a "Controller" for the application.
# @author Sayantam Dey

require 'erubis/engine/eruby'

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
    Hailstorm.application.connect_to_database()
  end
  
  # Processes the user commands and options
  def self.process_commands
    # relay to application instance
    Hailstorm.application.command_processor.execute()
  end

  attr_reader :command_processor

  def multi_threaded?
    @multi_threaded
  end

  def initialize
    @command_processor = Hailstorm::Support::CommandProcessor.new()
    @multi_threaded = true
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

    ActiveRecord::Base.logger = logger
    fail_once = false
    begin
      ActiveRecord::Base.establish_connection(connection_spec) # this is lazy, does not fail!
      # check if the database exists, create it otherwise - this will fail if database does not exist
      ActiveRecord::Base.connection.execute("SELECT count(id) from projects")
    rescue ActiveRecord::ActiveRecordError => e
      unless fail_once
        logger.debug "Database does not exist, creating..."
        # database does not exist yet
        create_database()

        # create/update the schema
        Hailstorm::Support::Schema.create_schema()

        fail_once = true
        retry
      else
        puts e.message()
        exit 1
      end
    end
  end
  
  # Initializes the application - creates directory structure and support files
  def init(invocation_path, arg_app_name)

    root_path = File.join(invocation_path, arg_app_name)
    FileUtils.mkpath(root_path)
    puts "(in #{invocation_path})"
    puts "  created directory: #{arg_app_name}"
    create_app_structure(root_path, arg_app_name)
    puts ""
    puts "Done!"
  end
  
  # Sets up the load agents and targets. 
  # Creates the load agents as needed and pushes the Jmeter scripts to the agents.
  # Pushes the monitoring artifacts to targets.
  def setup()
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

  # Implements the purge commands as per options
  def purge()

    case command_processor.purge_item
      when :tests
        current_project.execution_cycles.each {|e| e.destroy()}
        logger.info "Purged all data for tests"
      else
        current_project.destroy()
        @current_project = nil
        logger.info "Purged all project data"
    end
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

  def database_name()
    Hailstorm.app_name
  end

  def create_database()

    ActiveRecord::Base.establish_connection(connection_spec.merge(:database => nil))
    ActiveRecord::Base.connection.create_database(connection_spec[:database])
    ActiveRecord::Base.establish_connection(connection_spec)
  end

  def connection_spec

    if @connection_spec.nil?
      @connection_spec = {}

      # load the properties into a java.util.Properties instance
      database_properties_file = java.io.File.new(File.join(Hailstorm.root,
                                                            Hailstorm.config_dir,
                                                            "database.properties"))
      properties = java.util.Properties.new()
      properties.load(java.io.FileInputStream.new(database_properties_file))

      # load all properties without an empty value into the spec
      properties.each do |key, value|
        unless value.blank?
          @connection_spec[key.to_sym] = value
        end
      end

      # switch off multithread mode for sqlite & derby
      if @connection_spec[:adapter] =~ /(?:sqlite|derby)/i
        @multi_threaded = false
        @connection_spec[:database] = File.join(Hailstorm.root, Hailstorm.db_dir,
                                      "#{database_name}.db")
      else
        # set defaults which can be overridden
        @connection_spec = {
            :pool => 10,
            :wait_timeout => 30
        }.merge(@connection_spec).merge(:database => database_name)
      end
    end

    return @connection_spec
  end

  # Creates the application directory structure and adds files at appropriate
  # directories
  # @param [String] root_path the path this application will be rooted at
  # @param [String] arg_app_name the argument provided for creating project
  def create_app_structure(root_path, arg_app_name)

    # create directory structure
    dirs = [
      Hailstorm.db_dir,
      Hailstorm.app_dir,
      Hailstorm.log_dir,
      Hailstorm.tmp_dir,
      Hailstorm.reports_dir,
      Hailstorm.config_dir,
      Hailstorm.vendor_dir,
      Hailstorm.script_dir
    ]

    dirs.each do |dir|
      FileUtils.mkpath(File.join(root_path, dir))
      puts "    created directory: #{File.join(arg_app_name, dir)}"
    end

    skeleton_path = File.join(Hailstorm.templates_path, 'skeleton')

    # Copy to Gemfile
    FileUtils.copy(File.join(skeleton_path, 'Gemfile.erb'),
                   File.join(root_path, 'Gemfile'))
    puts "    wrote #{File.join(arg_app_name, 'Gemfile')}"

    # Copy to script/hailstorm
    hailstorm_script = File.join(root_path, Hailstorm.script_dir)
    FileUtils.copy(File.join(skeleton_path, 'hailstorm'),
                   hailstorm_script)
    FileUtils.chmod(0775, hailstorm_script) # make it executable
    puts "    wrote #{File.join(arg_app_name, Hailstorm.script_dir, 'hailstorm')}"

    # Copy to config/environment.rb
    FileUtils.copy(File.join(skeleton_path, 'environment.rb'),
                   File.join(root_path, Hailstorm.config_dir))
    puts "    wrote #{File.join(arg_app_name, Hailstorm.config_dir, 'environment.rb')}"

    # Copy to config/database.properties
    FileUtils.copy(File.join(skeleton_path, 'database.properties'),
                   File.join(root_path, Hailstorm.config_dir))
    puts "    wrote #{File.join(arg_app_name, Hailstorm.config_dir, 'database.properties')}"

    # Process to config/boot.rb
    cache_file_path = File.join(root_path, Hailstorm.tmp_dir,
                          'boot.erb.cache')
    engine = Erubis::Eruby.load_file(File.join(skeleton_path, 'boot.erb'),
                                     :cachename => cache_file_path)
    File.open(File.join(root_path, Hailstorm.config_dir, 'boot.rb'), 'w') do |f|
      f.print(engine.evaluate(:app_name => arg_app_name))
    end
    File.unlink(cache_file_path) # only need it once

    puts "    wrote #{File.join(arg_app_name, Hailstorm.config_dir, 'boot.rb')}"
  end

end
