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
      require self.cluster_type.underscore
      @cluster_klass = self.cluster_type.constantize()
    end
    @cluster_klass
  end

  def clusterables()
    cluster_klass.where(:project_id => self.project.id, :active => true)
  end

  # Configures the cluster implementation for use
  # @param [Hailstorm::Support::Configuration::ClusterBase] cluster_config cluster
  #   specific configuration instance
  def configure(cluster_config)

    logger.debug { "#{self.class}##{__method__}" }
    # cluster specific attributes
    cluster_attributes = cluster_config.instance_values
                                       .symbolize_keys
                                       .except(:active, :cluster_type)
    # find the cluster or create it
    cluster_instance = cluster_klass.where(cluster_attributes.merge(
                                        :project_id => self.project.id))
                                    .first_or_initialize(:active => cluster_config.active)

    if cluster_instance.new_record? and cluster_instance.active?
      cluster_instance.save!()
    end

    if cluster_instance.persisted?
      Hailstorm::Support::Thread.start(cluster_instance,
      cluster_attributes.merge(
      :active => cluster_config.active)) do |c, attr|

        c.setup(attr)
      end
    end
  end

  # Configures all clusters as per config.
  # @param [Hailstorm::Model::Project] project current project instance
  # @param [Hailstorm::Support::Configuration] config the configuration instance
  def self.configure_all(project, config)

    logger.debug { "#{self}.#{__method__}" }
    # disable all clusters and then create/update as per configuration
    project.clusters.each do |cluster|
      cluster.cluster_klass()
      .update_all({:active => false}, {:project_id => project.id})
    end

    config.clusters.each do |cluster_config|
      cluster_config.active = true if cluster_config.active.nil?
      if :amazon_cloud == cluster_config.cluster_type
        # eager-load 'AWS', since some parts of it are auto-loaded. autoloading
        # is apparently not thread safe.
        if require('aws')
          AWS.eager_autoload!
        end
      end
      cluster_type = "Hailstorm::Model::#{cluster_config.cluster_type.to_s.camelize}"
      cluster = project.clusters()
                       .where(:cluster_type => cluster_type)
                       .first_or_initialize()

      if cluster.new_record? and cluster_config.active
        cluster.save!()
      end
      cluster.configure(cluster_config) if cluster.persisted?
    end

    Hailstorm::Support::Thread.join()
  end

  # start load generation on clusters of a specific cluster_type
  def generate_load

    logger.debug { "#{self.class}##{__method__}" }
    clusterables.each do |cluster_instance|
      cluster_instance.before_generate_load()
      unless command.deploy_only?
        cluster_instance.start_slave_process() if self.project.master_slave_mode?
        cluster_instance.start_master_process()
      end
      cluster_instance.after_generate_load()
    end
  end

  # start load generation on all clusters in project
  # @param [Hailstorm::Model::Project] project current project instance
  def self.generate_all_load(project)

    logger.debug { "#{self}.#{__method__}" }
    project.clusters.each do |cluster|
      Hailstorm::Support::Thread.start(cluster) do |c|
        c.generate_load()
      end
    end

    Hailstorm::Support::Thread.join()
  end

  def stop_load_generation()

    logger.debug { "#{self.class}##{__method__}" }
    clusterables.each do |cluster_instance|
      cluster_instance.before_stop_load_generation()
      cluster_instance.stop_master_process()
      self.project.current_execution_cycle.collect_client_stats(cluster_instance)
      cluster_instance.after_stop_load_generation()
    end
  end

  def self.stop_load_generation(project)

    logger.debug { "#{self}.#{__method__}" }
    project.clusters.each do |cluster|
      Hailstorm::Support::Thread.start(cluster) do |c|
        c.stop_load_generation()
      end
    end

    Hailstorm::Support::Thread.join()

    # check if load generation is not stopped on any load agent and raise
    # exception accordingly
    unless Hailstorm::Model::LoadAgent.where("jmeter_pid IS NOT NULL").all.empty?
      raise(Hailstorm::Exception, "Jmeter could not be stopped on all agents")
    end

  end

  def terminate()

    logger.debug { "#{self.class}##{__method__}" }
    self.clusterables.each do |cluster_instance|
      cluster_instance.destroy_all_agents()
    end
  end

  def self.terminate(project)

    logger.debug { "#{self}.#{__method__}" }
    project.clusters.each do |cluster|
      Hailstorm::Support::Thread.start(cluster) do |c|
        c.terminate()
      end
    end

    Hailstorm::Support::Thread.join()
  end

  # @param [Hailstorm::Model::Project] project
  # @retutn [Terminal::Table]
  def self.to_text_table(project)

    terminal_table = Terminal::Table.new()
    terminal_table.title = 'Active Clusters'
    terminal_table.headings = ['Type', 'Properties']
    project.clusters.each do |cluster|
      cluster.clusterables.each do |clusterable|
        terminal_table.add_row([cluster.cluster_type.demodulize.tableize.singularize,
                                clusterable.public_properties()])
      end
    end

    return terminal_table
  end

  def destroy_clusterables
    cluster_klass.where(:project_id => self.project.id).each {|e| e.destroy()}
  end

  def command
    Hailstorm.application.command_processor
  end

end
