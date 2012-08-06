require 'java'

require 'ostruct'
require 'active_support/all'
require 'active_record'
require 'action_view'

require "hailstorm/version"

# Defines the namespace and module static accessors.
# @author Sayantam Dey
module Hailstorm

  # The application root path. Access this by calling <tt>Hailstorm.root</tt>
  @@root = nil
  mattr_reader :root #:nodoc:

  # Sets the root path of the application
  # @param [String] root path of application
  # @return [String]
  def self.root=(new_root)
    @@root = new_root
  end

  mattr_accessor :app_name

  mattr_accessor :application

  # Global logger object.
  # Can be set by <tt>Hailstorm.logger = ...</tt>.
  # This logger is injected into the Kernel module, so it is accessible to any
  # instance method.
  @@logger = nil

  # Creates and returns the global logger. The default is to use the Ruby Logger.
  # INFO, WARN messages are intended for end user, so the log message does not
  # include the caller string (point at which the logger method was invoked), other
  # levels carry this information.
  # @return [Logger]
  def self.logger()

    if @@logger.nil?
      @@logger = Logger.new(STDERR)
      @@logger.level = Logger::INFO
      @@logger.formatter = proc {|severity, datetime, progname, msg|
        msg.chomp! if msg.respond_to?(:chomp!)
        if %{INFO WARN}.include?(severity)
          "#{Thread.current.object_id}: #{datetime.strftime("%H:%M:%S")} [#{severity}] #{msg}\n"
        else
          "#{Thread.current.object_id}: #{datetime.strftime("%H:%M:%S")} [#{severity}] #{caller[4]} - #{msg}\n"
        end

      }
    end
    return @@logger
  end
  mattr_writer :logger #:nodoc:

  # :nodoc:
  @@subsystem_logger = nil
  def self.subsystem_logger()
    # Logger for subsystems - use this for noisy subsystems, meant for internal
    # use.
    if @@subsystem_logger.nil?
      @@subsystem_logger = Logger.new(STDERR)
      @@subsystem_logger.level = Logger::WARN
      @@subsystem_logger.formatter = proc {|severity, datetime, progname, msg|
        msg.chomp! if msg.respond_to?(:chomp!)
        "#{datetime.strftime("%H:%M:%S")} [#{severity}] #{msg}\n"
      }
    end
    return @@subsystem_logger
  end

  # Directory name used to store database and other files.
  def self.db_dir
    "db"
  end

  # Directory name for application specific (JMeter) artifacts
  def self.app_dir
    "jmeter"
  end

  def self.log_dir
    "log"
  end

  def self.tmp_dir
    "tmp"
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
    (ENV['HAILSTORM_ENV'] || 'production').to_sym
  end

end

# inject a logger method to Kernel so it's available everywhere
# TODO: Developer doc
Kernel.class_eval() do #:nodoc:
  def logger
    Hailstorm.logger
  end
end

# Add all Java Jars to classpath
java_lib = File.expand_path('../hailstorm/java/lib', __FILE__)
Dir[File.join(java_lib, '*.jar')].each do |jar|
  require(jar)
end


# after_commit methods simply log an error on exception and do not raise it
# monkey-patch to atleast log an additional backtrace,
# active_record/connection_adapters/abstract/database_statements.rb
module ActiveRecord
  module ConnectionAdapters
    module DatabaseStatements

      protected

      def commit_transaction_records
        records = @_current_transaction_records.flatten
        @_current_transaction_records.clear
        unless records.blank?
          records.uniq.each do |record|
            begin
              record.committed!
            rescue Exception => e
              if record.respond_to?(:logger) && record.logger
                record.logger.error("#{e.class}: #{e.message}")
                logger.debug { "\n".concat(e.backtrace().join("\n")) }
              end
            end
          end
        end
      end

    end
  end
end
