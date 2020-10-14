# frozen_string_literal: true

# Models mapping from a project to configured clusters
# @author Sayantam Dey

require 'haikunator'

require 'hailstorm/model'
require 'hailstorm/model/load_agent'
require 'hailstorm/support/thread'
require 'hailstorm/behavior/provisionable'
require 'hailstorm/behavior/clusterable'
require 'hailstorm/model/client_stat'
require 'hailstorm/support/collection_helper'
require 'hailstorm/support/aws_adapter'

# Base class for any platform (/Clusterable) that hosts the load generating set of nodes.
class Hailstorm::Model::Cluster < ActiveRecord::Base
  include Hailstorm::Support::CollectionHelper

  belongs_to :project
  before_create :set_cluster_code
  before_destroy :destroy_clusterable

  attr_accessor :slave_commands, :master_commands

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
    @cluster_instance ||= if self.clusterable_id.to_i.positive?
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
      def klass.configure_all(project, config, force: false)
        logger.debug { "#{self}.#{__method__}" }
        # disable all clusters and then create/update as per configuration
        project.clusters.reload.each do |cluster|
          cluster.cluster_instance.update_column(:active, false)
        end

        cluster_line_items = LifeCycle.create_base_clusters(config, force, project)
        LifeCycle.create_clusterables(cluster_line_items)
      end

      def klass.terminate(project)
        logger.debug { "#{self}.#{__method__}" }
        self.visit_collection(project.clusters.all, &:terminate)
      end
    end

    def self.create_base_clusters(config, force, project)
      cluster_line_items = []
      config.clusters.each do |cluster_config|
        cluster_config.active = true if cluster_config.active.nil?
        cluster = save_cluster!(cluster_config, project)
        cluster_line_items.push([cluster, cluster_config, force])
      end
      cluster_line_items
    end

    def self.create_clusterables(cluster_line_items)
      if cluster_line_items.size == 1
        cluster, cluster_config, force = cluster_line_items.first
        cluster.configure(cluster_config, force: force)
      elsif cluster_line_items.size > 1 # nothing to do if 0
        cluster_line_items.each do |line_item|
          Hailstorm::Support::Thread.start(line_item) do |li|
            cluster, cluster_config, force = li
            cluster.configure(cluster_config, force: force)
          end
        end
        Hailstorm::Support::Thread.join
      end
    end

    def self.save_cluster!(cluster_config, project)
      klass_name = "Hailstorm::Model::#{cluster_config.cluster_type.to_s.camelize}"
      cluster = Hailstorm::Model::Cluster.new(cluster_type: klass_name,
                                              cluster_code: cluster_config.cluster_code,
                                              project: project,
                                              clusterable_id: -1)
      cluster.set_cluster_code if cluster_config.cluster_code.nil?
      cluster
    end

    # Configures the cluster implementation for use
    # @param [Hailstorm::Support::Configuration::ClusterBase] cluster_config cluster
    #   specific configuration instance
    def configure(cluster_config, force: false)
      logger.debug { "#{self.class}##{__method__}" }
      # cluster specific attributes
      clusterable = find_clusterable_by_attrs(cluster_config)
      is_new_record = clusterable.new_record?
      clusterable.save!
      self.clusterable_id = clusterable.id
      if is_new_record
        self.save!
      else
        self.id = Hailstorm::Model::Cluster.where(clusterable_id: clusterable.id,
                                                  cluster_type: clusterable.class.name,
                                                  project_id: self.project.id).first.id
        self.reload
      end
      logger.debug { "#{self.cluster_type}##{self.clusterable_id} instance, proceeding to setup..." }
      clusterable.setup(force: force)
    end

    def find_clusterable_by_attrs(cluster_config)
      cluster_attributes = cluster_config.instance_values.symbolize_keys.except(
        :cluster_type,
        :cluster_code,
        :active,
        :max_threads_per_agent
      )

      cluster_attributes[:project_id] = self.project.id
      clusterable = cluster_klass.where(cluster_attributes).first_or_initialize
      clusterable.active = cluster_config.active
      if cluster_config.respond_to?(:max_threads_per_agent)
        clusterable.max_threads_per_agent = cluster_config.max_threads_per_agent
      end

      if clusterable.respond_to?(:machines) && !clusterable.machines.is_a?(Array)
        clusterable.machines = [clusterable.machines]
      end

      clusterable
    end

    def terminate
      logger.debug { "#{self.class}##{__method__}" }
      cluster_instance.destroy_all_agents do |agent|
        cluster_instance.before_destroy_load_agent(agent) if cluster_instance.is_a?(Hailstorm::Behavior::Provisionable)
        agent.transaction do
          agent.destroy
          cluster_instance.after_destroy_load_agent(agent) if cluster_instance.is_a?(Hailstorm::Behavior::Provisionable)
        end
      end
      cluster_instance.cleanup
    end
  end

  include LifeCycle

  # start load generation on clusters of a specific cluster_type
  def generate_load(redeploy: false)
    logger.debug { "#{self.class}##{__method__}" }
    return nil unless cluster_instance.active?

    cluster_instance.before_generate_load
    cluster_instance.start_slave_process(redeploy: redeploy) if self.project.master_slave_mode?
    cluster_instance.start_master_process(redeploy: redeploy)
    cluster_instance.after_generate_load
    cluster_instance
  end

  # start load generation on all clusters in project
  # @param [Hailstorm::Model::Project] project current project instance
  def self.generate_all_load(project, redeploy: false)
    logger.debug { "#{self}.#{__method__}" }
    mutex = Mutex.new
    cluster_instances = []
    self.visit_collection(project.clusters.all) do |c|
      ci = c.generate_load(redeploy: redeploy)
      mutex.synchronize { cluster_instances.push(ci) } if ci
    end
    cluster_instances
  end

  def stop_load_generation(wait: false, options: nil, aborted: false)
    logger.debug { "#{self.class}.#{__method__}" }
    return nil unless cluster_instance.active?

    cluster_instance.before_stop_load_generation
    cluster_instance.stop_master_process(wait: wait, aborted: aborted)
    logger.info "Load generation stopped at #{cluster_instance.slug}"
    unless aborted
      logger.info "Fetching logs from  #{cluster_instance.slug}..."
      Hailstorm::Model::ClientStat.collect_client_stats(self.project.current_execution_cycle,
                                                        cluster_instance)
    end
    cluster_instance.after_stop_load_generation(options)
    cluster_instance
  end

  def self.stop_load_generation(project, wait: false, options: nil, aborted: false)
    logger.debug { "#{self}.#{__method__}" }
    mutex = Mutex.new
    cluster_instances = []
    self.visit_collection(project.clusters.all) do |c|
      ci = c.stop_load_generation(wait: wait, options: options, aborted: aborted)
      mutex.synchronize { cluster_instances.push(ci) } if ci
    end

    # check if load generation is not stopped on any load agent and raise
    # exception accordingly
    agents_running = Hailstorm::Model::LoadAgent
                       .joins(jmeter_plan: :project)
                       .where(projects: { id: project.id }, load_agents: { active: true })
                       .where('load_agents.jmeter_pid IS NOT NULL')

    return cluster_instances if agents_running.empty?

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
    self.visit_collection(project.clusters.all) do |c|
      agents = c.check_status
      mutex.synchronize { running_agents.push(*agents) } unless agents.empty?
    end
    running_agents
  end

  def destroy_clusterable
    cluster_instance.destroy! unless cluster_instance.new_record?
  rescue ActiveRecord::RecordNotFound => e
    logger.warn(e.message)
  end

  def purge
    cluster_instance.purge if cluster_instance.active
  end

  def set_cluster_code
    return unless self.cluster_code.nil?

    self.cluster_code = Haikunator.haikunate(100) until self.class.where(cluster_code: self.cluster_code)
                                                            .count.zero?
  end
end
