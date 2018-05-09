require 'java'

# Defines the namespace and module static accessors.
# @author Sayantam Dey
module Hailstorm

  PRODUCTION_ENV = :production

  @@root = nil
  @@app_name = nil
  @@application = nil

  # The application root path. Access this by calling <tt>Hailstorm.root</tt>
  def self.root
    @@root
  end

  # Sets the root path of the application
  # @param [String] root path of application
  # @return [String]
  def self.root=(new_root)
    @@root = new_root
  end

  # Application name
  def self.app_name
    @@app_name
  end

  def self.app_name=(new_app_name)
    @@app_name = new_app_name
  end

  # Application instance
  def self.application
    @@application
  end

  def self.application=(new_application)
    @@application = new_application
  end

  # Directory name used to store database and other files.
  def self.db_dir
    'db'
  end

  # Directory name for application specific (JMeter) artifacts
  def self.app_dir
    'jmeter'
  end

  def self.log_dir
    'log'
  end

  def self.tmp_dir
    'tmp'
  end

  def self.tmp_path
    File.join(root, tmp_dir)
  end

  def self.templates_path
    File.expand_path('../../templates', __FILE__)
  end

  def self.reports_dir
    'reports'
  end

  def self.config_dir
    'config'
  end

  def self.vendor_dir
    'vendor'
  end

  def self.script_dir
    'script'
  end

  def self.environment_file_path
    File.join(self.root, self.config_dir, 'environment.rb')
  end

  def self.env
    (ENV['HAILSTORM_ENV'] || PRODUCTION_ENV).to_sym
  end

  def self.log4j_dir
    File.join(self.config_dir, 'log4j')
  end

  def self.results_import_dir
    File.join(self.log_dir, 'import')
  end

  def self.project_directories
    [
      Hailstorm.db_dir,
      Hailstorm.app_dir,
      Hailstorm.log_dir,
      Hailstorm.tmp_dir,
      Hailstorm.reports_dir,
      Hailstorm.config_dir,
      Hailstorm.vendor_dir,
      Hailstorm.script_dir
    ]
  end

  def self.is_production?
    self.env == PRODUCTION_ENV
  end
end
