# Project model.
# @author Sayantam Dey

require 'hailstorm'
require 'hailstorm/model'
require 'hailstorm/model/jmeter_plan'
require 'hailstorm/model/cluster'
require 'hailstorm/model/target_host'
require 'hailstorm/model/execution_cycle'

class Hailstorm::Model::Project < ActiveRecord::Base

  has_many :clusters, :dependent => :destroy
  
  has_many :jmeter_plans, :dependent => :destroy
  
  has_many :target_hosts, :dependent => :destroy
  
  has_many :execution_cycles, :dependent => :destroy
  
  has_one  :current_execution_cycle, :class_name => 'Hailstorm::Model::ExecutionCycle',
           :conditions => {:status => 'started'}, :order => "started_at DESC"

  before_save :set_defaults

  # Sets up the project for first time or subsequent use
  def setup(force = false)

    if force or settings_modified?
      logger.info("Setting up the project...")

      self.update_attributes!(:serial_version => config.serial_version(),
                              :max_threads_per_agent => config.max_threads_per_agent,
                              :master_slave_mode => config.master_slave_mode,
                              :samples_breakup_interval => config.samples_breakup_interval,
                              :jmeter_version => config.jmeter.version)
      
      begin
        configure_jmeter_plans()
        configure_clusters()
        configure_targets()
      rescue
        self.update_column(:serial_version, nil)
        raise
      end

    else
      raise(Hailstorm::Exception, "No changes to project configuration detected.")
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
          setup(true) #(force)
        rescue Exception
          self.current_execution_cycle.aborted!
          raise
        end
        self.reload()
      end
      self.current_execution_cycle.set_started_at(Time.now)

      Hailstorm::Model::TargetHost.monitor_all(self)
      Hailstorm::Model::Cluster.generate_all_load(self, redeploy)
    else
      # if one exists, user must stop/abort it first
      raise(Hailstorm::Exception,
            "You have already started an execution cycle at #{current_execution_cycle.started_at}. Please stop or abort first!")
    end
  end

  # Delegate to target_hosts and clusters
  def stop(wait = false, options = nil, aborted = false)
   
    logger.debug { "#{self.class}##{__method__}" }

    unless current_execution_cycle.nil?
      begin
        Hailstorm::Model::Cluster.stop_load_generation(self, wait, options, aborted)

        # Update the stopped_at now, so that target monitoring
        # statistics be collected from started_at to stopped_at
        current_execution_cycle.set_stopped_at()
        Hailstorm::Model::TargetHost.stop_all_monitoring(self, aborted)

        unless aborted
          current_execution_cycle.stopped!
        else
          current_execution_cycle.aborted!
        end

      rescue Hailstorm::Exception => ex
        # raised by stop_load_generation if load generation could not be stopped
        # on any agent
        logger.warn(ex.message)
      end
    else
      raise(Hailstorm::Exception, "Nothing to stop... no tests running")
    end
  end

  # Aborts everything immediately
  def abort(options = nil)
    
    logger.debug { "#{self.class}##{__method__}" }
    stop(false, options, true)
  end

  def terminate()
    
    logger.debug { "#{self.class}##{__method__}" }
    Hailstorm::Model::Cluster.terminate(self)
    Hailstorm::Model::TargetHost.terminate(self)
    unless current_execution_cycle.nil?
      current_execution_cycle.terminated!
    end
    self.update_column(:serial_version, nil)
  end

  def results(operation, cycle_ids = nil)

    logger.debug { "#{self.class}##{__method__}" }

    selected_execution_cycles =
        Hailstorm::Model::ExecutionCycle.execution_cycles_for_report(self,
                                                                     cycle_ids)
    if operation == :show # show tests
      return selected_execution_cycles

    elsif operation == :exclude # exclude
      selected_execution_cycles.each {|ex| ex.excluded!}

    elsif operation == :include # include
      selected_execution_cycles.each {|ex| ex.stopped!}

    else # generate report
      logger.info("Creating report for stopped tests...")
      report_path = Hailstorm::Model::ExecutionCycle.create_report(self, cycle_ids)
      logger.info { "Report generated to: #{report_path}" }
    end
  end

  def check_status()
    Hailstorm::Model::Cluster.check_status(self)
  end

  # Returns an array of load_agents as recorded in the database
  def load_agents()

    self.clusters()
        .reduce([]) {|acc, e| acc.push(*e.clusterables(true))}
        .reduce([]) {|acc, e| acc.push(*e.load_agents)}
  end

###################### PRIVATE METHODS #######################################
  private

  def configure_jmeter_plans()
    
    logger.info("Reading and validating JMeter plans...")
    Hailstorm::Model::JmeterPlan.setup(self)
  end

  # Persist the cluster configuration  
  def configure_clusters()
    
    logger.info("Setting up clusters...")
    Hailstorm::Model::Cluster.configure_all(self, config)
  end
  
  # Sets up targets for monitoring
  def configure_targets()

    logger.info("Setting up targets...")
    Hailstorm::Model::TargetHost.configure_all(self, config)
  end
  
  # @return [Boolean] true if configuration settings have been modified
  def settings_modified?
    (self.serial_version.nil? ||
        self.serial_version != config.serial_version()).tap do |modified|
      Hailstorm.application.load_config() if modified
    end
  end
  
  def config
    Hailstorm.application.config
  end

  def set_defaults()
    self.max_threads_per_agent ||= Defaults::MAX_THREADS_PER_AGENT
    self.master_slave_mode = Defaults::MASTER_SLAVE_MODE if self.master_slave_mode.nil?
    self.samples_breakup_interval ||= Defaults::SAMPLES_BREAKUP_INTERVAL
    self.jmeter_version ||= Defaults::JMETER_VERSION
  end

  # Default settings
  class Defaults
    MAX_THREADS_PER_AGENT = 50
    MASTER_SLAVE_MODE = false
    SAMPLES_BREAKUP_INTERVAL = '1,3,5'
    JMETER_VERSION = 2.7
  end

end
