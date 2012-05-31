# Represent a target host.
# @author Sayantam Dey

require 'hailstorm/model'
require 'hailstorm/behavior/moniterable'
require 'hailstorm/support/thread'

class Hailstorm::Model::TargetHost < ActiveRecord::Base
  
  include Hailstorm::Behavior::Moniterable
  
  belongs_to :project

  has_many :target_stats

  validates :host_name, :role_name, :presence => true, :if => proc {|r| r.active? }
 
  # require & create the class
  # @param [String] monitor_type fully qualified type of monitor
  # @return [Class] class from monitor_type     
  def self.moniterable_klass(monitor_type)
    require(monitor_type.underscore)
    monitor_type.constantize() 
  end

  # Calls #setup() and saves changes on success.
  def call_setup()
    
    begin
      setup()
      self.save!()
    rescue StandardError => e
      logger.error(e.message)
      self.update_column(:active, false)
      raise
    end
  end

  # Configures all targets as per config.
  # @param [Hailstorm::Model::Project] project current project instance
  # @param [Hailstorm::Support::Configuration] config the configuration instance
  def self.configure_all(project, config)
    
    logger.debug { "#{self}.#{__method__}" }
    # disable all hosts and delegate to monitor#setup to enable specific hosts 
    moniterables(project, false).each {|t| t.update_column(:active, false)}

    config.target_hosts.each do |host_def|
      next if host_def[:active] == false
      
      # update type nmemonic to real type
      host_def[:type] = "Hailstorm::Model::#{host_def[:type].to_s.camelize}"
      target_host = project.target_hosts()
                           .where(host_def.slice(:host_name, :type))
                           .first_or_initialize(host_def.except(:type))      
      
      unless target_host.persisted? # not persisted class -> TargetHost
        monitor = target_host.becomes(moniterable_klass(host_def[:type]))
      else
        monitor = target_host
      end
      if monitor.new_record? and monitor.active?
        monitor.save!()
      else
        monitor.update_attributes!(host_def) unless monitor.new_record?
      end
      
      # invoke configure in new thread
      Hailstorm::Support::Thread.start(monitor) {|t| t.call_setup()}
    end

    Hailstorm::Support::Thread.join()
  end

  # Calls #start_monitoring().
  # Saves states changes on success after method call.
  def call_start_monitoring()
    
    begin
      start_monitoring()
      self.save!()
    rescue StandardError => e
      logger.error(e.message)
      raise
    end
  end

  # Starts resource monitoring on all active target_hosts
  # @param [Hailstorm::Model::Project] project current project instance
  def self.monitor_all(project)

    logger.debug { "#{self}.#{__method__}" }
    moniterables(project).each do |target_host|
      Hailstorm::Support::Thread.start(target_host) {|t| t.call_start_monitoring()}
    end

    Hailstorm::Support::Thread.join()
  end

  # Calls #stop_monitoring() and persists state changes. After changes are
  # persisted, calls ExecutionCycle#collect_target_stats.
  def call_stop_monitoring()
    
    begin
      stop_monitoring()
      self.save!()
      logger.info "Monitoring stopped at #{self.host_name}"
      logger.info "Collecting usage data from #{self.host_name}..."
      self.project.current_execution_cycle.collect_target_stats(self)      
      
    rescue StandardError => e
      logger.error(e.message)
      raise
    end
  end

  # Stops monitoring on all target hosts. Each target_host is stopped in a new
  # thread. Blocks till all threads are done.
  def self.stop_all_monitoring(project)

    logger.debug { "#{self}.#{__method__}" }
    moniterables(project).each do |target_host|
      Hailstorm::Support::Thread.start(target_host) {|t| t.call_stop_monitoring()}
    end

    Hailstorm::Support::Thread.join()
  end

  # Calls #cleanup() and persists state changes
  def call_cleanup()
    
    begin
      cleanup()
      self.save!()
    rescue StandardError => e
      logger.error(e.message)
      raise
    end
  end

  def self.terminate(project)

    logger.debug { "#{self}.#{__method__}" }
    moniterables(project).each do |target_host|
      Hailstorm::Support::Thread.start(target_host) {|t| t.call_cleanup()}
    end

    Hailstorm::Support::Thread.join()
  end

  def self.moniterables(project, only_active = true)

    query = project.target_hosts
    if only_active
      query = query.where(:active => true)
    end
    query
  end

  # @param [Hailstorm::Model::ExecutionCycle] execution_cycle
  # @param [Array] log_file_paths
  def calculate_average_stats(execution_cycle, log_file_paths, &block)

    raise(ArgumentError, 'block required') unless block_given?
    logger.debug { "#{self.class}.#{__method__}" }

    @current_execution_context = execution_cycle.id
    analyze_log_files(log_file_paths, execution_cycle.started_at,
                      execution_cycle.stopped_at)

    stat = OpenStruct.new()
    stat.average_cpu_usage = average_cpu_usage(execution_cycle.started_at,
                                               execution_cycle.stopped_at)
    stat.average_memory_usage = average_memory_usage(execution_cycle.started_at,
                                                     execution_cycle.stopped_at)
    stat.average_swap_usage = average_swap_usage(execution_cycle.started_at,
                                                 execution_cycle.stopped_at)

    yield(stat)

    # remove log files
    unless log_file_paths.nil?
      log_file_paths.each {|f| File.unlink(f) }
    end
  end

  def self.to_text_table(project)

    active_target_hosts = project.target_hosts.where(:active => true).all()
    unless active_target_hosts.empty?
      terminal_table = Terminal::Table.new()
      terminal_table.title = 'Active Target Hosts'
      terminal_table.headings = ['Host', 'Role', 'Monitor', 'Executable', 'PID',
                                 'Interval', 'SSH Identity', 'User']

      active_target_hosts.each do |target_host|
        terminal_table.add_row([
                                   target_host.host_name,
                                   target_host.role_name,
                                   target_host.class.name.demodulize.tableize.singularize,
                                   target_host.executable_path,
                                   target_host.executable_pid,
                                   target_host.sampling_interval,
                                   target_host.ssh_identity,
                                   target_host.user_name
                               ])
      end

      terminal_table
    else
      ""
    end
  end

  protected

  # Returns an identifier which is unique for current execution cycle. Can
  # be used to named persistent data on disk or database
  def current_execution_context
    @current_execution_context || self.project.current_execution_cycle.id
  end

  # Computes a uniform name for a log file that is created by a monitor
  # implementation. The name does not have any extension, any suitable
  # extension can be applied by the monitor implementation.
  # The format of the name: host_#{full_host_name_like_this}-#{current_execution_cycle.id}
  # @return [String] file name
  def log_file_name()
    @log_file_name ||= sprintf(
        "host_%s-%d", self.host_name.gsub(/\./, '_'),
        self.project.current_execution_cycle.id)
  end

end
