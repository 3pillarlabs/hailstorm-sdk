# Models mapping from a project to configured clusters
# @author Sayantam Dey

require 'haikunator'

require 'hailstorm/model'
require 'hailstorm/model/load_agent'
require 'hailstorm/support/thread'

# Base class for any platform (/Clusterable) that hosts the load generating set of nodes.
class Hailstorm::Model::Cluster < ActiveRecord::Base

  belongs_to :project
  before_create :set_cluster_code
  before_destroy :destroy_clusterable

  attr_accessor :slave_commands
  attr_accessor :master_commands

  # @return [Class] the model class represented by cluster_type.
  def cluster_klass
    if @cluster_klass.nil?
      begin
        @cluster_klass = self.cluster_type.constantize
      rescue Exception
        require(self.cluster_type.underscore)
        retry
      end
    end
    @cluster_klass
  end

  # @return [Hailstorm::Behavior::Clusterable] instance
  def cluster_instance(attrs = {})
    @cluster_instance ||= if self.clusterable_id.to_i > 0
                            cluster_klass.find(self.clusterable_id)
                          else
                            cluster_klass.new(attrs)
                          end
  end

  # Cluster life-cycle methods
  module LifeCycle
    def self.included(klass)
      # Configures all clusters as per config.
      # @param [Hailstorm::Model::Project] project current project instance
      # @param [Hailstorm::Support::Configuration] config the configuration instance
      # @raise [Hailstorm::Exception] if one or more clusters could not be started
      def klass.configure_all(project, config, force = false)
        logger.debug { "#{self}.#{__method__}" }
        # disable all clusters and then create/update as per configuration
        project.clusters.each do |cluster|
          cluster.cluster_instance.update_column(:active, false)
        end

        cluster_line_items = LifeCycle.create_base_clusters(config, force, project)
        LifeCycle.create_clusterables(cluster_line_items)
      end

      def klass.terminate(project)
        logger.debug { "#{self}.#{__method__}" }
        self.visit_clusters(project, &:terminate)
      end
    end

    def self.create_base_clusters(config, force, project)
      cluster_line_items = []
      config.clusters.each do |cluster_config|
        cluster_config.active = true if cluster_config.active.nil?
        # eager-load 'AWS', since some parts of it are auto-loaded. autoloading
        # is apparently not thread safe.
        AWS.eager_autoload! if cluster_config.aws_required? && require('aws')
        cluster = save_cluster!(cluster_config, project)
        cluster_line_items.push([cluster, cluster_config, force])
      end
      cluster_line_items
    end

    def self.create_clusterables(cluster_line_items)
      if cluster_line_items.size == 1
        cluster, cluster_config, force = cluster_line_items.first
        cluster.configure(cluster_config, force)
      elsif cluster_line_items.size > 1 # nothing to do if 0
        cluster_line_items.each do |line_item|
          Hailstorm::Support::Thread.start(line_item) do |li|
            cluster, cluster_config, force = li
            cluster.configure(cluster_config, force)
          end
        end
        Hailstorm::Support::Thread.join
      end
    end

    def self.save_cluster!(cluster_config, project)
      conditions = { cluster_type: "Hailstorm::Model::#{cluster_config.cluster_type.to_s.camelize}",
                     clusterable_id: nil }
      conditions[:cluster_code] = cluster_config.cluster_code if cluster_config.cluster_code
      cluster = project.clusters.where(conditions).first_or_initialize
      cluster.clusterable_id = -1 if cluster.new_record?
      cluster.set_cluster_code if cluster.cluster_code.nil?
      cluster.save!
      cluster
    end

    # Configures the cluster implementation for use
    # @param [Hailstorm::Support::Configuration::ClusterBase] cluster_config cluster
    #   specific configuration instance
    def configure(cluster_config, force = false)
      logger.debug { "#{self.class}##{__method__}" }
      # cluster specific attributes
      cluster_attributes = extract_attrs(cluster_config)
      cluster_instance(cluster_attributes).save!
      self.update_column(:clusterable_id, cluster_instance.id)
      logger.debug { "Saved #{self.cluster_type}##{self.clusterable_id} instance, proceeding to setup..." }
      cluster_instance.setup(force)
    end

    def extract_attrs(cluster_config)
      cluster_attributes = cluster_config.instance_values.symbolize_keys.except(:cluster_type, :cluster_code)
      cluster_attributes[:project_id] = self.project.id
      cluster_attributes
    end

    def terminate
      logger.debug { "#{self.class}##{__method__}" }
      cluster_instance.destroy_all_agents
      cluster_instance.cleanup
    end
  end

  include LifeCycle

  # start load generation on clusters of a specific cluster_type
  def generate_load(redeploy = false)
    logger.debug { "#{self.class}##{__method__}" }
    cluster_instance.before_generate_load
    cluster_instance.start_slave_process(redeploy) if self.project.master_slave_mode?
    cluster_instance.start_master_process(redeploy)
    cluster_instance.after_generate_load
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
    cluster_instance.before_stop_load_generation
    cluster_instance.stop_master_process(wait, aborted)
    logger.info "Load generation stopped at #{cluster_instance.slug}"
    unless aborted
      logger.info "Fetching logs from  #{cluster_instance.slug}..."
      self.project.current_execution_cycle.collect_client_stats(cluster_instance)
    end
    cluster_instance.after_stop_load_generation(options)
  end

  def self.stop_load_generation(project, wait = false, options = nil, aborted = false)
    logger.debug { "#{self}.#{__method__}" }
    self.visit_clusters(project) do |c|
      c.stop_load_generation(wait, options, aborted)
    end

    # check if load generation is not stopped on any load agent and raise
    # exception accordingly
    return if Hailstorm::Model::LoadAgent.where('jmeter_pid IS NOT NULL').all.empty?
    raise(Hailstorm::Exception, 'Load generation could not be stopped on all agents')
  end

  # Checks if JMeter is running on different clusters and returns array of
  # MasterAgent instances where JMeter is running or empty array if JMeter
  # is not running on any agent.
  # @return [Array] of Hailstorm::Model::MasterAgent instances
  def check_status
    logger.debug { "#{self.class}##{__method__}" }
    mutex = Mutex.new
    running_agents = []
    agents = cluster_instance.check_status
    mutex.synchronize { running_agents.push(*agents) } unless agents.empty?
    running_agents
  end

  def self.check_status(project)
    logger.debug { "#{self}.#{__method__}" }
    mutex = Mutex.new
    running_agents = []
    self.visit_clusters(project) do |c|
      agents = c.check_status
      mutex.synchronize { running_agents.push(*agents) } unless agents.empty?
    end

    running_agents
  end

  def destroy_clusterable
    cluster_instance.destroy! unless cluster_instance.new_record?
  end

  def self.visit_clusters(project, &_block)
    project_clusters = project.clusters.all
    if project_clusters.count == 1
      yield project_clusters.first
    else
      project_clusters.each do |cluster|
        Hailstorm::Support::Thread.start(cluster) { |c| yield c }
      end
      Hailstorm::Support::Thread.join
    end
  end

  def purge
    cluster_klass.purge if cluster_klass.respond_to?(:purge)
  end

  def set_cluster_code
    return unless self.cluster_code.nil?
    self.cluster_code = Haikunator.haikunate(100) until self.class.where(cluster_code: self.cluster_code)
                                                            .count.zero?
  end
end
