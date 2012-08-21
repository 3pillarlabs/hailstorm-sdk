require 'java'

require 'ostruct'
require 'active_support/all'
require 'active_record'
require 'action_view'

require "hailstorm/version"
require "hailstorm/behavior/loggable"

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
class Object
  include Hailstorm::Behavior::Loggable
end

# after_commit methods simply log an error on exception and do not raise it
# monkey-patch to at least log an additional backtrace,
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
