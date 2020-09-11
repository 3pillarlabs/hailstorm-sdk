# frozen_string_literal: true

require 'hailstorm/model/concern'

# Method implementations for `Provisionable` interface
module Hailstorm::Model::Concern::ProvisionableHelper

  # start the agent and update agent ip_address and identifier
  def start_agent(load_agent)
    return if load_agent.running?

    instance = load_agent.identifier ? restart_agent_instance(load_agent) : create_agent_instance(load_agent)

    # copy attributes
    load_agent.identifier = instance.instance_id
    load_agent.public_ip_address = instance.public_ip_address
    load_agent.private_ip_address = instance.private_ip_address
  end

  # stop the load agent
  def stop_agent(load_agent)
    if load_agent.identifier
      agent_ec2_instance = instance_client.find(instance_id: load_agent.identifier)
      if agent_ec2_instance.running?
        logger.info("Stopping agent##{load_agent.identifier}...")
        instance_client.stop(instance_id: load_agent.identifier)
        wait_for("#{agent_ec2_instance.id} to stop",
                 err_attrs: { region: self.region }) { instance_client.stopped?(instance_id: agent_ec2_instance) }
      end
    else
      logger.warn('Could not stop agent as identifier is not available')
    end
  end

  # Start load agents if not started
  # (see Hailstorm::Behavior::Clusterable::LoadAgentHelper#before_generate_load)
  def before_generate_load
    logger.debug { "#{self.class}##{__method__}" }
    self.load_agents.where(active: true).each do |agent|
      unless agent.running?
        start_agent(agent)
        agent.save!
      end
    end
  end

  # Process the suspend option. Must be specified as {:suspend => true}
  # @param [Hash] options
  # (see Hailstorm::Behavior::Clusterable::LoadAgentHelper#after_stop_load_generation)
  def after_stop_load_generation(options = nil)
    logger.debug { "#{self.class}##{__method__}" }
    suspend = (options.nil? ? false : options[:suspend])
    return unless suspend

    self.load_agents.where(active: true).each do |agent|
      next unless agent.running?

      stop_agent(agent)
      agent.public_ip_address = nil
      agent.save!
    end
  end

  # Terminate load agent
  # (see Hailstorm::Behavior::Provisionable#before_destroy_load_agent)
  def before_destroy_load_agent(load_agent)
    agent_ec2_instance = instance_client.find(instance_id: load_agent.identifier)
    if agent_ec2_instance
      logger.info("Terminating agent##{load_agent.identifier}...")
      instance_client.terminate(instance_id: agent_ec2_instance.id)
      logger.debug { "Waiting for #{agent_ec2_instance.id} to terminate..." }
      wait_for("#{agent_ec2_instance.id} on #{self.region} region to terminate") do
        instance_client.terminated?(instance_id: agent_ec2_instance.id)
      end
    else
      logger.warn("Agent ##{load_agent.identifier} does not exist on EC2")
    end
  end

  def required_load_agent_count(jmeter_plan)
    if self.respond_to?(:max_threads_per_agent) && jmeter_plan.num_threads > self.max_threads_per_agent
      (jmeter_plan.num_threads.to_f / self.max_threads_per_agent).ceil
    else
      1
    end
  end

  private

  def create_agent_instance(load_agent)
    instance = create_agent
    instance_name = "#{self.project.project_code}-#{load_agent.class.name.underscore}-#{load_agent.id}"
    instance_client.tag_name(resource_id: instance.id, name: instance_name)
    instance
  end

  def restart_agent_instance(load_agent)
    instance = instance_client.find(instance_id: load_agent.identifier)
    restart_agent(instance_id: instance.id, stopped: instance.stopped?)
  end

  def restart_agent(instance_id:, stopped:)
    if stopped
      logger.info("Restarting agent##{instance_id}...")
      instance_client.start(instance_id: instance_id)
    end

    wait_for("agent##{instance_id} to restart",
             err_attrs: { region: self.region }) { instance_client.running?(instance_id: instance_id) }

    instance_client.find(instance_id: instance_id)
  end

  def create_agent
    logger.info("Starting new agent on #{self.region}...")
    security_group = security_group_finder.find_security_group
    ec2_instance_helper.create_ec2_instance(ami_id: self.agent_ami, security_group_ids: security_group.id)
  end
end
