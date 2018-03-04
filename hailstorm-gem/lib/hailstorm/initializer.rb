require 'hailstorm'

# Initializer for Hailstorm project
module Hailstorm::Initializer

  # Creates the application directory structure and adds files at appropriate
  # directories
  # @param [String] invocation_path the path this application will be installed
  # @param [String] arg_app_name the argument provided for creating project
  # @param [Boolean] quiet false, by default; set true to not emit to stdout
  # @param [String] gem_path local path to gem installation
  # @return [String] root_path local path to the application root
  def self.create_project!(invocation_path, arg_app_name, quiet = false, gem_path = nil)
    require 'hailstorm/initializer/eager_load'
    require 'hailstorm/initializer/project_structure'
    project_creator = Hailstorm::Initializer::ProjectStructure.new(invocation_path, arg_app_name, quiet, gem_path)
    project_creator.create_app_structure
  end

  # Initialize Hailstorm for all applications
  # @param [String] app_name the application name
  # @param [String] boot_file_path full path to application config/boot.rb
  # @param [Hash] connection_spec map of properties for the database connection
  # @param [Hailstorm::Support::Configuration] env_config config object
  # @return [Hailstorm::Middleware::Application] initialized application middleware
  def self.create_middleware(app_name, boot_file_path, connection_spec = nil, env_config = nil)
    Hailstorm.app_name = app_name
    Hailstorm.root = File.expand_path('../..', boot_file_path)
    require 'hailstorm/initializer/eager_load'
    require 'hailstorm/initializer/log_config'
    require 'hailstorm/initializer/java_classpath'
    require 'hailstorm/initializer/tmp_directory'
    require 'hailstorm/middleware/application'
    require 'hailstorm/middleware/command_interpreter'
    Hailstorm::Middleware::Application.initialize(connection_spec, env_config).tap do |middleware|
      middleware.command_interpreter = Hailstorm::Middleware::CommandInterpreter.new
    end
  end
end
