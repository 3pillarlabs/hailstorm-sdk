# frozen_string_literal: true

require 'hailstorm/support'
require 'hailstorm/behavior/loggable'
require 'hailstorm/exceptions'

# Standalone script to remove all artifacts associated with an Amazon account -
# Instances, AMI, Snapshots, Key Pairs and Security Groups from every region
# @author Sayantam Dey
class Hailstorm::Support::AmazonAccountCleaner
  include Hailstorm::Behavior::Loggable

  attr_reader :doze_seconds,
              :region_code,
              :resource_group,
              :client_factory

  # Resource group for resources to be removed
  class AccountResourceGroup
    attr_reader :instance_ids,
                :ami_id,
                :security_group_name,
                :key_pair_name,
                :subnet_id,
                :vpc_id

    # @param [Hash] attrs Hash#keys instance_ids ami_id security_group_name key_pair_name subnet_id vpc_id
    def initialize(attrs = {})
      @instance_ids = attrs[:instance_ids] || []
      @ami_id = attrs[:ami_id]
      @security_group_name = attrs[:security_group_name]
      @key_pair_name = attrs[:key_pair_name]
      @subnet_id = attrs[:subnet_id]
      @vpc_id = attrs[:vpc_id]
    end
  end

  CLEANUP_STEPS_ATTR_MAPS = [
    %i[terminate_instances instance_ids],
    %i[delete_key_pairs key_pair_name],
    %i[deregister_amis ami_id],
    %i[delete_security_groups security_group_name],
    %i[delete_subnet subnet_id],
    %i[delete_vpc vpc_id]
  ].freeze

  # @param [Hash] client_factory
  # @param [String] region_code
  # @param [AccountResourceGroup] resource_group
  def initialize(client_factory:,
                 region_code:,
                 resource_group: AccountResourceGroup.new,
                 doze_seconds: 5)
    @client_factory = client_factory
    @region_code = region_code
    @resource_group = resource_group
    @doze_seconds = doze_seconds
  end

  def cleanup
    logger.info "Cleaning up in AWS Region #{region_code}..."
    all_steps = determine_cleanup_steps
    completed_steps = []
    begin
      all_steps.each do |step|
        send(step)
        completed_steps.push(step)
      end
      logger.info "Cleanup Done in AWS Region #{region_code}!"
    rescue Hailstorm::AwsException => error
      cleanup_error = Hailstorm::AwsException.new("#{error.message}. All remaining steps were skipped.")
      cleanup_error.retryable = error.retryable?
      cleanup_error.data = all_steps - completed_steps
      logger.debug do
        "Cleanup in AWS Region #{region_code} failed with pending steps: #{cleanup_error.data.join(', ')}"
      end

      raise(cleanup_error)
    end
  end

  private

  def determine_cleanup_steps
    CLEANUP_STEPS_ATTR_MAPS.each_with_object([]) do |attr_map, steps_to_execute|
      step, resource_attr = attr_map
      steps_to_execute.push(step) unless resource_group.send(resource_attr).blank?
    end
  end

  def terminate_instances
    client_factory.instance_client.list(instance_ids: resource_group.instance_ids).each do |instance|
      next if instance.status == :terminated

      logger.info { "Terminating instance##{instance.id}..." }
      client_factory.instance_client.terminate(instance_id: instance.id)
      sleep(doze_seconds) until client_factory.instance_client.terminated?(instance_id: instance.id)
      logger.info { "... instance##{instance.id} terminated" }
    end
  end

  def delete_key_pairs
    key_pair_id = client_factory.key_pair_client.find(name: resource_group.key_pair_name)
    return if key_pair_id.blank?

    client_factory.key_pair_client.delete(key_pair_id: key_pair_id)
    logger.info { "Key pair##{resource_group.key_pair_name} deleted" }
  end

  def deregister_amis
    image = find_ami
    return if image.nil? || !image.available?

    logger.info { "Deregistering AMI##{image.id}..." }
    client_factory.ami_client.deregister(ami_id: image.id)
    logger.info { "... AMI##{image.id} deregistered" }

    logger.info { "Deleting snapshot##{image.snapshot_id}" }
    client_factory.ec2_client.delete_snapshot(snapshot_id: image.snapshot_id)
    logger.info { "... snapshot##{image.snapshot_id} deleted" }
  end

  def find_ami
    client_factory.ami_client.find(ami_id: resource_group.ami_id, filters: [:created])
  rescue Hailstorm::AwsException
    nil
  end

  def delete_security_groups
    security_group = client_factory.security_group_client.find(name: resource_group.security_group_name,
                                                               vpc_id: resource_group.vpc_id,
                                                               filters: [:created])
    return if security_group.nil?

    client_factory.security_group_client.delete(group_id: security_group.id)
    logger.info { "Security group##{resource_group.security_group_name} deleted" }
  end

  def delete_subnet
    subnet_id = begin
                  client_factory.subnet_client.find(subnet_id: resource_group.subnet_id, filters: [:created])
                rescue StandardError
                  nil
                end
    return if subnet_id.nil?

    client_factory.subnet_client.delete(subnet_id: subnet_id)
    logger.info { "Subnet##{subnet_id} deleted" }
  end

  def delete_vpc
    vpc = client_factory.vpc_client.find(vpc_id: resource_group.vpc_id, filters: [:created])
    return if vpc.nil?

    # VPC can't be deleted till sub-resources are deleted
    delete_routing_tables
    delete_internet_gateways
    client_factory.vpc_client.delete(vpc_id: vpc.id)
    logger.info { "VPC##{vpc.id} deleted" }
  end

  # Delete routing table created by Hailstorm
  def delete_routing_tables
    client_factory
      .route_table_client
      .route_tables(vpc_id: resource_group.vpc_id, filters: [:created])
      .reject(&:main)
      .each do |route_table|

      client_factory.route_table_client.delete(route_table_id: route_table.id)
    end
  end

  # Delete internet gateway
  def delete_internet_gateways
    client_factory
      .internet_gateway_client
      .select(vpc_id: resource_group.vpc_id, filters: [:created])
      .each do |igw|

      client_factory.internet_gateway_client.detach_from_vpc(igw_id: igw.id, vpc_id: resource_group.vpc_id)
      client_factory.internet_gateway_client.delete(igw_id: igw.id)
    end
  end
end
