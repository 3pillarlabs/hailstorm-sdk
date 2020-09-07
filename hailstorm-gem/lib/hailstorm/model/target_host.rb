# frozen_string_literal: true

require 'hailstorm/model'
require 'hailstorm/model/target_stat'
require 'hailstorm/behavior/moniterable'
require 'hailstorm/support/thread'

# Represent a target host.
# @author Sayantam Dey
class Hailstorm::Model::TargetHost < ActiveRecord::Base

  include Hailstorm::Behavior::Moniterable

  belongs_to :project

  has_many :target_stats

  validates :host_name, :role_name, :sampling_interval, presence: true, if: proc { |r| r.active? }

  scope :active, -> { where(active: true) }

  scope :natural_order, -> { order('role_name') }

  # require & create the class
  # @param [String] monitor_type fully qualified type of monitor
  # @return [Class] class from monitor_type
  def self.moniterable_klass(monitor_type)
    monitor_type.constantize
  rescue Exception
    require(monitor_type.to_s.underscore)
    retry
  end

  # Calls #setup() and saves changes on success.
  def do_setup
    setup if self.active?
    self.save!
  rescue StandardError => e
    logger.error(e.message)
    self.update_column(:active, false)
    raise
  end

  # Configures all targets as per config.
  # @param [Hailstorm::Model::Project] project current project instance
  # @param [Hailstorm::Support::Configuration] config the configuration instance
  def self.configure_all(project, config)
    logger.debug { "#{self}.#{__method__}" }
    # disable all hosts and delegate to monitor#setup to enable specific hosts
    moniterables(project, only_active: false).each { |t| t.update_column(:active, false) }

    host_definitions(config.monitors).each do |host_def|
      # update type nmemonic to real type
      monitor = _to_monitor(host_def, project)
      # invoke configure in new thread
      Hailstorm::Support::Thread.start(monitor, &:do_setup)
    end

    begin
      Hailstorm::Support::Thread.join
    rescue StandardError
      raise(Hailstorm::Exception, 'One or more target hosts could not be setup for monitoring.')
    end
  end

  def self._to_monitor(host_def, project)
    host_def[:type] = "Hailstorm::Model::#{host_def[:type].to_s.camelize}"
    target_host = project.target_hosts
                         .where(host_def.slice(:host_name, :type))
                         .first_or_initialize(host_def.except(:type))

    if target_host.new_record?
      monitor = target_host.becomes(moniterable_klass(host_def[:type]))
      monitor.save!
    else
      monitor = target_host
      target_host.update!(host_def)
    end
    monitor
  end

  # Calls #start_monitoring().
  # Saves states changes on success after method call.
  def do_start_monitoring
    start_monitoring
    self.save!
  rescue StandardError => e
    logger.error(e.message)
    raise
  end

  # Starts resource monitoring on all active target_hosts
  # @param [Hailstorm::Model::Project] project current project instance
  def self.monitor_all(project)
    logger.debug { "#{self}.#{__method__}" }
    moniterables(project).each do |target_host|
      Hailstorm::Support::Thread.start(target_host, &:do_start_monitoring)
    end

    begin
      Hailstorm::Support::Thread.join
    rescue StandardError
      raise(Hailstorm::Exception, 'Monitoring could not be started on one or more hosts')
    end
  end

  # Calls #stop_monitoring() and persists state changes. After changes are
  # persisted, calls ExecutionCycle#collect_target_stats.
  def do_stop_monitoring
    stop_monitoring
    self.save!
    logger.info "Monitoring stopped at #{self.host_name}"
  rescue StandardError => e
    logger.error(e.message)
    raise
  end

  # Stops monitoring on all target hosts. Each target_host is stopped in a new
  # thread. Blocks till all threads are done.
  def self.stop_all_monitoring(project, execution_cycle, create_target_stat: true)
    logger.debug { "#{self}.#{__method__}" }
    moniterables(project).each do |target_host|
      Hailstorm::Support::Thread.start(target_host) do |t|
        t.do_stop_monitoring
        Hailstorm::Model::TargetStat.create_target_stat(execution_cycle, t) if create_target_stat
      end
    end

    begin
      Hailstorm::Support::Thread.join
    rescue StandardError
      raise(Hailstorm::Exception, 'Monitoring could not be stopped on one or more hosts')
    end
  end

  # Calls #cleanup() and persists state changes
  def do_cleanup
    cleanup
    self.save!
  rescue StandardError => e
    logger.error(e.message)
    raise
  end

  def self.terminate(project)
    logger.debug { "#{self}.#{__method__}" }
    moniterables(project).each do |target_host|
      Hailstorm::Support::Thread.start(target_host, &:do_cleanup)
    end

    begin
      Hailstorm::Support::Thread.join
    rescue StandardError
      raise(Hailstorm::Exception, 'Monitoring could not be terminated on one or more hosts')
    end
  end

  def self.moniterables(project, only_active: true)
    query = project.target_hosts
    query = query.where(active: true) if only_active
    query
  end

  # Iterates through the moniters and returns the host definitions
  # @param [Array<Hailstorm::Support::Configuration::TargetHost>] monitors
  # @return [Array] of Hash, with attributes mapped to Hailstorm::Model::TargetHost
  def self.host_definitions(monitors)
    logger.debug { "#{self.class}##{__method__}" }
    host_defs = []
    monitors.each do |monitor|
      monitor.groups.each do |group|
        group.hosts.each do |host|
          hdef = host.instance_values.symbolize_keys
          hdef[:type] = monitor.monitor_type
          hdef[:role_name] = group.role
          %i[executable_path ssh_identity user_name
             sampling_interval active].each do |sym|

            # take values from monitor unless the hdef contains the key
            hdef[sym] = monitor.send(sym) unless hdef.key?(sym)
          end
          hdef[:active] = true if hdef[:active].nil?
          host_defs.push(hdef)
        end
      end
    end
    host_defs
  end

  protected

  # Returns an identifier which is unique for current execution cycle. Can
  # be used to named persistent data on disk or database
  def current_execution_context
    @current_execution_context ||= self.project.current_execution_cycle.id
  end

  # Computes a uniform name for a log file that is created by a monitor
  # implementation. The name does not have any extension, any suitable
  # extension can be applied by the monitor implementation.
  # The format of the name: host_#{full_host_name_like_this}-#{current_execution_cycle.id}
  # @return [String] file name
  def log_file_name
    @log_file_name ||= format('host_%<host_name>s-%<execution_id>d',
                              host_name: self.host_name.tr('.', '_'),
                              execution_id: self.project.current_execution_cycle.id)
  end
end
