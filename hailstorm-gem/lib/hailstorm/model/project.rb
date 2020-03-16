require 'uri'

require 'hailstorm'
require 'hailstorm/model'
require 'hailstorm/model/jmeter_plan'
require 'hailstorm/model/cluster'
require 'hailstorm/model/target_host'
require 'hailstorm/model/execution_cycle'
require 'hailstorm/model/jmeter_installer_url_validator'
require 'hailstorm/model/jmeter_version_validator'
require 'hailstorm/support/jmeter_installer'

# Project model.
# @author Sayantam Dey
class Hailstorm::Model::Project < ActiveRecord::Base
  has_many :clusters, dependent: :destroy

  has_many :jmeter_plans, dependent: :destroy

  has_many :target_hosts, dependent: :destroy

  has_many :execution_cycles, dependent: :destroy

  has_one  :current_execution_cycle, -> { where(status: 'started').order('started_at DESC') },
           class_name: 'Hailstorm::Model::ExecutionCycle'

  validates_presence_of :project_code

  validates :custom_jmeter_installer_url, 'Hailstorm::Model::JmeterInstallerUrl' => true,
                                          if: ->(r) { r.custom_jmeter_installer_url }
  validates :jmeter_version, 'Hailstorm::Model::JmeterVersion' => true, if: ->(r) { r.jmeter_version }

  before_save :set_defaults

  attr_writer :settings_modified

  after_initialize { |project| project.settings_modified = false }

  after_create :create_workspace

  # Services for commands
  module ServiceInterface
    # Sets up the project for first time or subsequent use
    # @param [Boolean] force
    # @param [Boolean] invoked_from_start
    # @param [Hailstorm::Support::Configuration] config
    def setup(config:, force: false, invoked_from_start: false)
      unless invoked_from_start || settings_modified? || force
        raise(Hailstorm::Exception, 'No changes to project configuration detected.')
      end

      logger.info('Setting up the project...')
      save_config_attrs!(config)
      begin
        setup_jmeter_plans(config)
        configure_clusters(config, force)
        configure_target_hosts(config)
        self.reload
        self.settings_modified = false
      rescue Exception
        self.update_column(:serial_version, nil)
        raise
      end
    end

    # Starts the load generation and target monitoring tasks
    def start(redeploy: false, config:)
      logger.debug { "#{self.class}##{__method__}" }

      # if one exists, user must stop/abort it first
      unless self.current_execution_cycle.nil?
        raise Hailstorm::ExecutionCycleExistsException, current_execution_cycle.started_at
      end

      # add an execution_cycle
      build_current_execution_cycle.save! # buildABC is provided by has_one :ABC relation
      redo_setup(config)
      self.current_execution_cycle.started!

      begin
        Hailstorm::Model::TargetHost.monitor_all(self)
        Hailstorm::Model::Cluster.generate_all_load(self, redeploy)
      rescue Exception
        self.current_execution_cycle.aborted!
        raise
      ensure
        self.current_execution_cycle.update_attribute(:threads_count, estimate_threads_count)
        self.reload
      end
    end

    # Delegate to target_hosts and clusters
    def stop(wait = false, options = nil, aborted = false)
      logger.debug { "#{self.class}##{__method__}" }
      raise(Hailstorm::ExecutionCycleNotExistsException) if current_execution_cycle.nil?

      stop_target_monitoring = true
      begin
        Hailstorm::Model::Cluster.stop_load_generation(self, wait, options, aborted)
        update_execution_cycle(aborted)
      rescue Exception => exception
        if jmeter_running_on_all?(exception)
          stop_target_monitoring = false
        else
          current_execution_cycle.aborted!
        end

        raise
      ensure
        if stop_target_monitoring
          did_abort = !(aborted || current_execution_cycle.aborted?)
          Hailstorm::Model::TargetHost.stop_all_monitoring(self,
                                                           current_execution_cycle,
                                                           create_target_stat: did_abort)
        end

        self.reload
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
      self.reload
    end

    def results(operation, cycle_ids: nil, format: nil, config:)
      logger.debug { "#{self.class}##{__method__}" }
      selected_execution_cycles = if operation != :import
                                    Hailstorm::Model::ExecutionCycle.execution_cycles_for_report(self, cycle_ids)
                                  else
                                    []
                                  end
      executor = ResultsOperationExecutor.new(self, cycle_ids, selected_execution_cycles, format)
      executor.logger = logger
      executor.config = config
      if operation && executor.respond_to?(operation)
        executor.send(operation)
      else
        executor.report
      end
    end

    def check_status
      Hailstorm::Model::Cluster.check_status(self)
    end

    # Returns an array of load_agents as recorded in the database
    def load_agents
      self.clusters.map(&:cluster_instance).reduce([]) { |acc, e| acc.push(*e.load_agents) }
    end

    # Purges all clusters in the project
    def purge_clusters
      self.clusters.each(&:purge)
    end

    private

    def jmeter_running_on_all?(exception)
      exception.is_a?(Hailstorm::ThreadJoinException) &&
        exception.exceptions.all? { |ex| ex.is_a?(Hailstorm::JMeterRunningException) }
    end

    # Update the stopped_at now, so that target monitoring
    # statistics be collected from started_at to stopped_at
    def update_execution_cycle(aborted)
      current_execution_cycle.set_stopped_at
      if !aborted
        current_execution_cycle.stopped!
        total_threads_count = self.current_execution_cycle.client_stats.sum(:threads_count)
        self.current_execution_cycle.update_attribute(:threads_count, total_threads_count)
      else
        current_execution_cycle.aborted!
      end
    end

    def estimate_threads_count
      self.jmeter_plans.sum(:latest_threads_count) * self.clusters.map(&:cluster_instance).select(&:active?).size
    end

    def redo_setup(config)
      return unless settings_modified?

      begin
        setup(invoked_from_start: true, config: config, force: true)
      rescue Exception
        self.current_execution_cycle.aborted!
        raise
      ensure
        self.reload
      end
    end
  end

  include ServiceInterface

  def settings_modified?
    @settings_modified
  end

  ###################### PRIVATE METHODS #######################################
  private

  # Extract attributes from config
  def save_config_attrs!(config)
    self.master_slave_mode = config.master_slave_mode
    self.samples_breakup_interval = config.samples_breakup_interval
    if config.jmeter.custom_installer_url
      url = config.jmeter.custom_installer_url
      if config.jmeter.version
        logger.warn("Custom installer '#{url}' overrides configured version '#{config.jmeter.version}'")
      end
      self.custom_jmeter_installer_url = url
    else
      self.jmeter_version = config.jmeter.version
    end

    self.save!
  end

  # @param [Hailstorm::Support::Configuration] config
  def setup_jmeter_plans(config)
    logger.info('Reading and validating JMeter plans...')
    Hailstorm::Model::JmeterPlan.setup(self, config)
  end

  def configure_clusters(config, force)
    logger.info('Setting up clusters...')
    Hailstorm::Model::Cluster.configure_all(self, config, force)
  end

  def configure_target_hosts(config)
    logger.info('Setting up targets...')
    Hailstorm::Model::TargetHost.configure_all(self, config)
  end

  def set_defaults
    self.master_slave_mode = Defaults::MASTER_SLAVE_MODE if self.master_slave_mode.nil?
    self.samples_breakup_interval ||= Defaults::SAMPLES_BREAKUP_INTERVAL
    self.jmeter_version ||= if self.custom_jmeter_installer_url.blank?
                              Defaults::JMETER_VERSION
                            else
                              strategy_klass = Hailstorm::Support::JmeterInstaller::Tarball::DownloadUrlStrategy
                              strategy_klass.extract_jmeter_version(self.custom_jmeter_installer_url)
                            end
    self.project_code.gsub!(/[\W]+/, '_')
  end

  def create_workspace
    Hailstorm.workspace(self.project_code).create_file_layout
  end

  # Executes results operations
  class ResultsOperationExecutor

    attr_reader :project, :cycle_ids, :execution_cycles, :format
    attr_accessor :logger, :config

    def initialize(project, cycle_ids, execution_cycles, format)
      @project = project
      @cycle_ids = cycle_ids
      @execution_cycles = execution_cycles
      @format = format
    end

    def show
      execution_cycles
    end

    def exclude
      raise(Hailstorm::Exception, 'missing argument') if cycle_ids.blank?

      execution_cycles.each(&:excluded!)
    end

    def include
      raise(Hailstorm::Exception, 'missing argument') if cycle_ids.blank?

      execution_cycles.each(&:stopped!)
    end

    def export
      export_dir_path = Hailstorm.workspace(project.project_code).tmp_path
      execution_cycles.each do |ex|
        seq_path = File.join(export_dir_path, "SEQUENCE-#{ex.id}")
        FileUtils.mkdir_p(seq_path)
        ex.export_results(seq_path)
      end
      zip_path = zip_exports(export_dir_path) if format.to_s.to_sym == :zip
      Hailstorm.fs.export_jtl(self.project.project_code, zip_path || export_dir_path)
    end

    def import
      project.setup(force: false, invoked_from_start: false, config: self.config) if project.settings_modified?
      jtl_file_paths, options = cycle_ids
      options = options ? options.symbolize_keys : {}
      jmeter_plan = jmeter_plan(options)
      cluster_instance = cluster_instance(options)
      jtl_file_paths.each do |remote_path|
        execution_cycle = execution_cycle(options)
        local_path = Hailstorm.fs.copy_jtl(project.project_code,
                                           from_path: remote_path,
                                           to_path: Hailstorm.workspace(project.project_code).tmp_path)
        execution_cycle.import_results(jmeter_plan, cluster_instance, local_path)
      end
    end

    def report
      logger.info('Creating report for stopped tests...')
      local_report_path = Hailstorm::Model::ExecutionCycle.create_report(project, cycle_ids)
      return if local_report_path.blank?

      Hailstorm.fs.export_report(project.project_code, local_report_path)
    end

    private

    def execution_cycle(options)
      if options.key?(:exec)
        project.execution_cycles.where(id: options[:exec]).first
      else
        project.execution_cycles.create!(status: Hailstorm::Model::ExecutionCycle::States::STOPPED,
                                         started_at: Time.now)
      end
    end

    def cluster_instance(options)
      if options.key?(:cluster)
        project.clusters.where(cluster_code: options[:cluster]).first.cluster_instance
      else
        project.clusters.all.first.cluster_instance
      end
    end

    def jmeter_plan(options)
      if options.key?(:jmeter)
        project.jmeter_plans.where(test_plan_name: options[:jmeter]).first
      else
        project.jmeter_plans.all.first
      end
    end

    def zip_exports(path)
      timestamp = Time.now.strftime('%Y%m%d%H%M%S')
      zip_file_path = File.join(Hailstorm.workspace(project.project_code).tmp_path, "jtl-#{timestamp}.zip")
      FileUtils.safe_unlink(zip_file_path)
      Zip::File.open(zip_file_path, Zip::File::CREATE) do |zf|
        execution_cycles.each do |ex|
          seq_dir = "SEQUENCE-#{ex.id}"
          zf.mkdir(seq_dir)
          Dir["#{path}/#{seq_dir}/*.jtl"].each do |jtl_file|
            ze = "#{seq_dir}/#{File.basename(jtl_file)}"
            zf.add(ze, jtl_file) { true }
          end
        end
      end

      zip_file_path
    end
  end

  # Default settings
  class Defaults
    MASTER_SLAVE_MODE = false
    SAMPLES_BREAKUP_INTERVAL = '1,3,5'.freeze
    JMETER_VERSION = 3.2
  end
end
