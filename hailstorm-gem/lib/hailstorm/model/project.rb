# Project model.
# @author Sayantam Dey

require 'uri'

require 'hailstorm'
require 'hailstorm/model'
require 'hailstorm/model/jmeter_plan'
require 'hailstorm/model/cluster'
require 'hailstorm/model/target_host'
require 'hailstorm/model/execution_cycle'

class Hailstorm::Model::Project < ActiveRecord::Base
  has_many :clusters, dependent: :destroy

  has_many :jmeter_plans, dependent: :destroy

  has_many :target_hosts, dependent: :destroy

  has_many :execution_cycles, dependent: :destroy

  has_one  :current_execution_cycle, -> { where(status: 'started') },
           class_name: 'Hailstorm::Model::ExecutionCycle', order: 'started_at DESC'

  validate :custom_jmeter_installer_url_format

  before_save :set_defaults

  # Sets up the project for first time or subsequent use
  # @param [Boolean] force
  # @param [Boolean] invoked_from_start
  def setup(force = false, invoked_from_start = false)
    if invoked_from_start || settings_modified? || force
      logger.info('Setting up the project...')

      if config.jmeter.custom_installer_url
        if config.jmeter.version
          logger.warn do
            "Ignoring configured version '#{config.jmeter.version}' because custom installer '#{config.jmeter.custom_installer_url}' specified"
          end
        end

        self.custom_jmeter_installer_url = config.jmeter.custom_installer_url
        self.jmeter_version = jmeter_version_from_installer_url
      else
        self.jmeter_version = config.jmeter.version
      end

      updated_attrs = {
        serial_version: config.serial_version,
        master_slave_mode: config.master_slave_mode,
        samples_breakup_interval: config.samples_breakup_interval
      }
      self.update_attributes!(updated_attrs)

      begin
        logger.info('Reading and validating JMeter plans...')
        Hailstorm::Model::JmeterPlan.setup(self)

        logger.info('Setting up clusters...')
        Hailstorm::Model::Cluster.configure_all(self, config, force)

        logger.info('Setting up targets...')
        Hailstorm::Model::TargetHost.configure_all(self, config)
      rescue
        self.update_column(:serial_version, nil)
        raise
      end

    else
      raise(Hailstorm::Exception, 'No changes to project configuration detected.')
    end
  end

  # Starts the load generation and target monitoring tasks
  def start(redeploy = false)
    logger.debug { "#{self.class}##{__method__}" }

    # add an execution_cycle
    if current_execution_cycle.nil?
      build_current_execution_cycle.save! # buildABC is provided by has_one :ABC relation
      if settings_modified?
        begin
          setup(false, true) # (force, invoked_from_start)
        rescue Exception
          self.current_execution_cycle.aborted!
          raise
        end
        self.reload
      end
      self.current_execution_cycle.set_started_at(Time.now)

      begin
        Hailstorm::Model::TargetHost.monitor_all(self)
        Hailstorm::Model::Cluster.generate_all_load(self, redeploy)
      rescue
        self.current_execution_cycle.aborted!
        raise
      end

    else
      # if one exists, user must stop/abort it first
      raise(Hailstorm::Exception,
            "You have already started an execution cycle at #{current_execution_cycle.started_at}. Please stop or abort first!")
    end
  end

  # Delegate to target_hosts and clusters
  def stop(wait = false, options = nil, aborted = false)
    logger.debug { "#{self.class}##{__method__}" }
    if current_execution_cycle.nil?
      raise(Hailstorm::Exception, 'Nothing to stop... no tests running')
    else
      load_gen_stopped = false
      begin
        Hailstorm::Model::Cluster.stop_load_generation(self, wait, options, aborted)
        load_gen_stopped = true

        # Update the stopped_at now, so that target monitoring
        # statistics be collected from started_at to stopped_at
        current_execution_cycle.set_stopped_at

        Hailstorm::Model::TargetHost.stop_all_monitoring(self, aborted)

        if aborted
          current_execution_cycle.aborted!
        else
          current_execution_cycle.stopped!
        end
      rescue
        Hailstorm::Model::TargetHost.stop_all_monitoring(self, true) unless load_gen_stopped
        current_execution_cycle.aborted!
        raise
      end
    end
  end

  # Aborts everything immediately
  def abort(options = nil)
    logger.debug { "#{self.class}##{__method__}" }
    stop(false, options, true)
  end

  def terminate
    logger.debug { "#{self.class}##{__method__}" }
    Hailstorm::Model::Cluster.terminate(self)
    Hailstorm::Model::TargetHost.terminate(self)
    current_execution_cycle.terminated! unless current_execution_cycle.nil?
    self.update_column(:serial_version, nil)
  end

  def results(operation, cycle_ids = nil)
    logger.debug { "#{self.class}##{__method__}" }

    selected_execution_cycles =
      Hailstorm::Model::ExecutionCycle.execution_cycles_for_report(self,
                                                                   cycle_ids)
    case operation
    when :show
      return selected_execution_cycles
    when :exclude
      raise(Hailstorm::Exception, 'missing argument') if cycle_ids.blank?
      selected_execution_cycles.each(&:excluded!)
    when :include
      raise(Hailstorm::Exception, 'missing argument') if cycle_ids.blank?
      selected_execution_cycles.each(&:stopped!)
    when :export
      selected_execution_cycles.each do |ex|
        export_paths = ex.export_results
        logger.info { "Results exported to:\n#{export_paths.join("\n")}" }
      end
    when :import
      do_import(cycle_ids)
    else
      # generate report
      logger.info('Creating report for stopped tests...')
      report_path = Hailstorm::Model::ExecutionCycle.create_report(self, cycle_ids)
      logger.info { "Report generated to: #{report_path}" } unless report_path.blank?
    end
  end

  def check_status
    Hailstorm::Model::Cluster.check_status(self)
  end

  # Returns an array of load_agents as recorded in the database
  def load_agents
    self.clusters
        .reduce([]) { |acc, e| acc.push(*e.clusterables(true)) }
        .reduce([]) { |acc, e| acc.push(*e.load_agents) }
  end

  # Purges all clusters in the project
  def purge_clusters
    self.clusters.each(&:purge)
  end

  CUSTOM_JMETER_URL_REXP_1 = /[\-_]([\d\.\w]+)\.ta?r?\.?gz$/
  CUSTOM_JMETER_URL_REXP_2 = /(\w+)\.ta?r?\.?gz$/

  attr_accessor :custom_jmeter_installer_url

  def custom_jmeter_installer_file
    File.basename(URI(self.custom_jmeter_installer_url).path) if self.custom_jmeter_installer_url
  end

  def custom_jmeter_dir_name
    /^(.+?)\.ta?r?\.?gz$/ =~ custom_jmeter_installer_file && Regexp.last_match(1)
  end

  ###################### PRIVATE METHODS #######################################
  private

  # @return [Boolean] true if configuration settings have been modified
  def settings_modified?
    (self.serial_version.nil? ||
        self.serial_version != config.serial_version).tap do |modified|
      Hailstorm.application.load_config if modified
    end
  end

  def config
    Hailstorm.application.config
  end

  def set_defaults
    self.master_slave_mode = Defaults::MASTER_SLAVE_MODE if self.master_slave_mode.nil?
    self.samples_breakup_interval ||= Defaults::SAMPLES_BREAKUP_INTERVAL
    self.jmeter_version ||= Defaults::JMETER_VERSION if self.custom_jmeter_installer_url.blank?
  end

  def jmeter_version_from_installer_url
    [CUSTOM_JMETER_URL_REXP_1, CUSTOM_JMETER_URL_REXP_2].each do |rexp|
      match_data = rexp.match(self.custom_jmeter_installer_url)
      return match_data[1] if match_data
    end
  end

  def custom_jmeter_installer_url_format
    if self.custom_jmeter_installer_url
      if CUSTOM_JMETER_URL_REXP_1 !~ self.custom_jmeter_installer_url && CUSTOM_JMETER_URL_REXP_2 !~ self.custom_jmeter_installer_url
        self.errors.add(:custom_jmeter_installer_url, 'must be a gzip tar ending with .tgz or .tar.gz')
      end
    end
  end

  def do_import(cycle_ids)
    self.setup(force = false, invoked_from_start = false) if settings_modified?
    jtl_file_paths = []
    file_path, options = cycle_ids
    options = options ? options.symbolize_keys : {}
    if file_path.nil?
      glob = File.join(Hailstorm.root, Hailstorm.results_import_dir, '*.jtl')
      Dir[glob].sort.each {|fp| jtl_file_paths << fp}
    else
      jtl_file_paths << file_path
    end
    jmeter_plan = if options.key?(:jmeter)
                    self.jmeter_plans.where(test_plan_name: options[:jmeter]).first
                  else
                    self.jmeter_plans.all.first
                  end

    cluster_instance = if options.key?(:cluster)
                         self.clusters.where(cluster_code: options[:cluster]).first.clusterables(all = true).first
                       else
                         self.clusters.all.first.clusterables(all = true).first
                       end
    jtl_file_paths.each do |jfp|
      exec_cycle = if options.key?(:exec)
                     self.execution_cycles.where(id: options[:exec]).first
                   else
                     self.execution_cycles.create!(
                         status: Hailstorm::Model::ExecutionCycle::States::STOPPED,
                         started_at: Time.now
                     )
                   end
      exec_cycle.import_results(jmeter_plan, cluster_instance, jfp)
    end
  end

  # Default settings
  class Defaults
    MASTER_SLAVE_MODE = false
    SAMPLES_BREAKUP_INTERVAL = '1,3,5'.freeze
    JMETER_VERSION = 3.2
  end
end
