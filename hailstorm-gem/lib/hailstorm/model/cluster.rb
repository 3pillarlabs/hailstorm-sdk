# Models mapping from a project to configured clusters
# @author Sayantam Dey

require 'hailstorm/model'
require 'hailstorm/model/load_agent'
require 'hailstorm/support/thread'

class Hailstorm::Model::Cluster < ActiveRecord::Base

  belongs_to :project

  before_destroy :destroy_clusterables

  attr_accessor :slave_commands

  attr_accessor :master_commands

  # @return [Class] the model class represented by cluster_type.
  def cluster_klass()
    if @cluster_klass.nil?
      begin
        @cluster_klass = self.cluster_type.constantize
      rescue
        require(self.cluster_type.underscore)
        retry
      end
    end
    @cluster_klass
  end

  # Pass all = true to get all clusterables, where active or inactive.
  # Default value is false, which means only active clusterables are returned.
  # @param [Boolean] all
  # @return [Array]
  def clusterables(all = false)
    cluster_klass.where(
        {:project_id => self.project.id}.merge(all ? {} : {:active => true}))
  end

  # Configures the cluster implementation for use
  # @param [Hailstorm::Support::Configuration::ClusterBase] cluster_config cluster
  #   specific configuration instance
  def configure(cluster_config, force = false)

    logger.debug { "#{self.class}##{__method__}" }
    # cluster specific attributes
    cluster_attributes = cluster_config.instance_values
                                       .symbolize_keys
                                       .except(:active, :cluster_type, :max_threads_per_agent)
                                       .merge(:project_id => self.project.id)
    # find the cluster or create it
    cluster_instance = cluster_klass.where(cluster_attributes)
                                    .first_or_initialize()
    cluster_instance.active = cluster_config.active
    if cluster_instance.respond_to?(:max_threads_per_agent)
      cluster_instance.max_threads_per_agent = cluster_config.max_threads_per_agent
    end
    cluster_instance.setup(force)
  end

  # Configures all clusters as per config.
  # @param [Hailstorm::Model::Project] project current project instance
  # @param [Hailstorm::Support::Configuration] config the configuration instance
  # @raise [Hailstorm::Exception] if one or more clusters could not be started
  def self.configure_all(project, config, force = false)

    logger.debug { "#{self}.#{__method__}" }
    # disable all clusters and then create/update as per configuration
    project.clusters.each do |cluster|
      cluster.cluster_klass()
             .where({:project_id => project.id}).update_all({:active => false})
    end

    cluster_line_items = []
    config.clusters.each do |cluster_config|
      cluster_config.active = true if cluster_config.active.nil?
      # eager-load 'AWS', since some parts of it are auto-loaded. autoloading
      # is apparently not thread safe.
      if cluster_config.aws_required? and require('aws')
        AWS.eager_autoload!
      end
      cluster_type = "Hailstorm::Model::#{cluster_config.cluster_type.to_s.camelize}"
      cluster = project.clusters()
                       .where(:cluster_type => cluster_type)
                       .first_or_create!

      cluster_line_items.push([cluster, cluster_config, force])
    end

    if cluster_line_items.size == 1
      cluster, cluster_config, force = cluster_line_items.first
      cluster.configure(cluster_config, force)
    elsif cluster_line_items.size > 1 # nothing to do if 0
      cluster_line_items.each do |line_item|
        Hailstorm::Support::Thread.start(line_item) do |cluster, cluster_config, force|
          cluster.configure(cluster_config, force)
        end
      end
      Hailstorm::Support::Thread.join()
    end

  end

  # start load generation on clusters of a specific cluster_type
  def generate_load(redeploy = false)

    logger.debug { "#{self.class}##{__method__}" }
    visit_clusterables do |ci|
      ci.before_generate_load()
      ci.start_slave_process(redeploy) if self.project.master_slave_mode?
      ci.start_master_process(redeploy)
      ci.after_generate_load()
    end
  end

  # start load generation on all clusters in project
  # @param [Hailstorm::Model::Project] project current project instance
  def self.generate_all_load(project, redeploy = false)

    logger.debug { "#{self}.#{__method__}" }
    self.visit_clusters(project) do |c|
      c.generate_load(redeploy)
    end
  end

  def stop_load_generation(wait = false, options = nil, aborted = false)

    logger.debug { "#{self.class}##{__method__}" }
    visit_clusterables do |ci|
      ci.before_stop_load_generation()
      ci.stop_master_process(wait, aborted)
      logger.info "Load generation stopped at #{ci.slug}"
      unless aborted
        logger.info "Fetching logs from  #{ci.slug}..."
        self.project.current_execution_cycle.collect_client_stats(ci)
      end
      ci.after_stop_load_generation(options)
    end
  end

  def self.stop_load_generation(project, wait = false, options = nil, aborted = false)

    logger.debug { "#{self}.#{__method__}" }
    self.visit_clusters(project) do |c|
      c.stop_load_generation(wait, options, aborted)
    end

    # check if load generation is not stopped on any load agent and raise
    # exception accordingly
    unless Hailstorm::Model::LoadAgent.where("jmeter_pid IS NOT NULL").all.empty?
      raise(Hailstorm::Exception, "Load generation could not be stopped on all agents")
    end
  end

  def terminate()

    logger.debug { "#{self.class}##{__method__}" }
    visit_clusterables(true) do |ci|
      ci.destroy_all_agents()
      ci.cleanup()
    end
  end

  def self.terminate(project)

    logger.debug { "#{self}.#{__method__}" }
    self.visit_clusters(project) do |c|
      c.terminate()
    end
  end

  # Checks if JMeter is running on different clusters and returns array of
  # MasterAgent instances where JMeter is running or empty array if JMeter
  # is not running on any agent.
  # @return [Array] of Hailstorm::Model::MasterAgent instances
  def check_status()

    logger.debug { "#{self.class}##{__method__}" }
    mutex = Mutex.new()
    running_agents = []
    self.visit_clusterables do |cluster_instance|
      agents = cluster_instance.check_status()
      unless agents.empty?
        mutex.synchronize { running_agents.push(*agents) }
      end
    end
    return running_agents
  end

  def self.check_status(project)

    logger.debug { "#{self}.#{__method__}" }
    mutex = Mutex.new()
    running_agents = []
    self.visit_clusters(project) do |c|
      agents = c.check_status()
      unless agents.empty?
        mutex.synchronize {
          running_agents.push(*agents)
        }
      end
    end

    return running_agents
  end

  def destroy_clusterables
    clusterables(true).each {|e| e.destroy()}
  end

  def visit_clusterables(all = false, &block)

    self_clusterables = self.clusterables(all)
    if self_clusterables.count == 1
      yield self_clusterables.first
    else
      self_clusterables.each do |cluster_instance|
        Hailstorm::Support::Thread.start(cluster_instance) do |ci|
          yield ci
        end
      end
      Hailstorm::Support::Thread.join()
    end
  end

  def self.visit_clusters(project, &block)

    project_clusters = project.clusters().all()
    if project_clusters.count == 1
      yield project_clusters.first
    else
      project_clusters.each do |cluster|
        Hailstorm::Support::Thread.start(cluster) do |c|
          yield c
        end
      end
      Hailstorm::Support::Thread.join()
    end
  end

  def purge()
    if cluster_klass.respond_to?(:purge)
      cluster_klass.purge()
    end
  end

end
