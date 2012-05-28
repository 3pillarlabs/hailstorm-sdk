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

  # Sets up the project for first time or subsequent use
  def setup(show_table_info = true)

    if command.force_setup? or settings_modified?
      logger.info("Setting up the project...")
      updateable_attributes = {:serial_version => config.serial_version()}
      
      updateable_attributes.merge!(
        :max_threads_per_agent => config.max_threads_per_agent
      ) unless config.max_threads_per_agent.nil?
      
      updateable_attributes.merge!(
        :master_slave_mode => config.master_slave_mode
      ) unless config.master_slave_mode.nil?

      updateable_attributes.merge!(
          :samples_breakup_interval => config.samples_breakup_interval
      ) unless config.samples_breakup_interval.nil?

      updateable_attributes.merge!(
          :jmeter_version => config.jmeter.version
      ) unless config.jmeter.version.nil?
      
      self.update_attributes!(updateable_attributes)
      
      begin
        configure_jmeter_plans()
        configure_clusters()
        configure_targets()
        to_text_table() if show_table_info
      rescue
        self.update_column(:serial_version, nil)
        raise
      end

    else
      logger.info("No changes to project configuration detected.")
    end
  end

  # Starts the load generation and target monitoring tasks
  def start()
   
    logger.debug { "#{self.class}##{__method__}" }
    
    # add an execution_cycle
    if current_execution_cycle.nil?
      build_current_execution_cycle(:status => :started).save!
      if settings_modified?
        begin
          setup(false)
        rescue Exception
          self.current_execution_cycle.update_attribute(:status, :broken)
          raise
        end
        self.reload()
      end
      self.current_execution_cycle.set_started_at(Time.now)

      Hailstorm::Model::TargetHost.monitor_all(self)
      Hailstorm::Model::Cluster.generate_all_load(self)
      to_cluster_text_table()
      to_monitor_text_table()
    else
      # if one exists, user must stop/abort it first
      logger.warn("You have already started an execution cycle at #{current_execution_cycle.started_at}")
      logger.info("Please stop or abort first!")
    end
  end

  # Delegate to target_hosts and clusters
  def stop()
   
    logger.debug { "#{self.class}##{__method__}" }

    unless current_execution_cycle.nil?
      begin
        Hailstorm::Model::Cluster.stop_load_generation(self)

        # Update the stopped_at now, so that target monitoring
        # statistics be collected from started_at to stopped_at
        current_execution_cycle.set_stopped_at()
        Hailstorm::Model::TargetHost.stop_all_monitoring(self)

        unless command.aborted?
          current_execution_cycle.update_attribute(:status, :stopped)
        else
          current_execution_cycle.update_attribute(:status, :aborted)
        end
        to_cluster_text_table()
        to_monitor_text_table()

      rescue Hailstorm::Exception
        # raised by stop_load_generation if load generation could not be stopped
        # on any agent
      end
    else
      logger.info "Nothing to stop... no tests running"
    end
  end

  # Aborts everything
  def abort()
    
    logger.debug { "#{self.class}##{__method__}" }
    stop()
  end

  def terminate()
    
    logger.debug { "#{self.class}##{__method__}" }
    Hailstorm::Model::Cluster.terminate(self)
    Hailstorm::Model::TargetHost.terminate(self)
    unless current_execution_cycle.nil?
      current_execution_cycle.update_attribute(:status, :terminated)
    end
    self.update_column(:serial_version, nil)
    to_cluster_text_table()
    to_monitor_text_table()
  end

  def generate_report()

    logger.debug { "#{self.class}##{__method__}" }
    if command.report_show_tests?
      text_table = Terminal::Table.new()
      text_table.headings = ['Sequence', 'Started', 'Stopped', 'Threads']
      text_table.rows = Hailstorm::Model::ExecutionCycle.execution_cycles_for_report(self)
                                                        .collect do |execution_cycle|
        [
            execution_cycle.id,
            execution_cycle.formatted_started_at,
            execution_cycle.formatted_stopped_at,
            execution_cycle.total_threads_count
        ]
      end
      puts text_table.to_s
    elsif command.report_exclude_sequence
      self.execution_cycles
          .find(command.report_exclude_sequence)
          .update_column(:status, 'excluded')

    elsif command.report_include_sequence
      self.execution_cycles
          .find(command.report_include_sequence)
          .update_column(:status, 'stopped')

    elsif command.report_sequence_list
      self.execution_cycles
          .find(command.report_sequence_list)
          .each {|e| e.update_column(:status, 'stopped')}

    else
      logger.info("Creating report for stopped tests...")
      report_path = Hailstorm::Model::ExecutionCycle.create_report(self)
      logger.info { "Report generated to: #{report_path}" }
    end
  end

  # Implements the "show" command
  def show()

    case command.show_setup
      when :jmeter
        to_jmeter_plan_text_table()
      when :cluster
        to_cluster_text_table()
      when :monitor
        to_monitor_text_table()
      when :status
        unless self.current_execution_cycle.nil?
          running_agents = Hailstorm::Model::Cluster.check_status(self)
          unless running_agents.empty?
            logger.info "Load generation running on following load agents:"
            text_table = Terminal::Table.new()
            text_table.headings = ['Cluster', 'Agent', 'PID']
            text_table.rows = running_agents.collect {|agent|
              [agent.clusterable.slug, agent.public_ip_address, agent.jmeter_pid]
            }
            puts text_table.to_s
          else
            logger.info "Load generation finished on all load agents"
          end
        else
          logger.info "No tests have been started"
        end
      else
        to_text_table()
    end
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

  def command
    Hailstorm.application.command_processor
  end

  def to_text_table()
    to_jmeter_plan_text_table()
    to_cluster_text_table()
    to_monitor_text_table()
  end

  def to_jmeter_plan_text_table()
    puts Hailstorm::Model::JmeterPlan.to_text_table(self).to_s
  end

  def to_cluster_text_table()
    puts Hailstorm::Model::Cluster.to_text_table(self).to_s
    to_load_agents_text_table()
  end

  def to_monitor_text_table()
    puts Hailstorm::Model::TargetHost.to_text_table(self).to_s
  end

  def to_load_agents_text_table()
    puts Hailstorm::Model::LoadAgent.to_text_table(self).to_s
  end

end
