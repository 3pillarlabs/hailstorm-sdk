# frozen_string_literal: true

require 'hailstorm/support'
require 'hailstorm/model/helper/amazon_cloud_defaults'
require 'hailstorm/behavior/loggable'

# Standalone script to remove all artifacts associated with an Amazon account -
# Instances, AMI, Snapshots, Key Pairs and Security Groups from every region
# @author Sayantam Dey
class Hailstorm::Support::AmazonAccountCleaner
  include Hailstorm::Behavior::Loggable

  attr_reader :doze_seconds,
              :region_code,
              :ec2_client,
              :key_pair_client,
              :security_group_client,
              :instance_client, :ami_client

  def initialize(client_factory:, region_code:, doze_seconds: 5)
    @region_code = region_code
    @doze_seconds = doze_seconds
    @default_security_group = Hailstorm::Model::Helper::AmazonCloudDefaults::SECURITY_GROUP
    @ec2_client = client_factory.ec2_client
    @key_pair_client = client_factory.key_pair_client
    @security_group_client = client_factory.security_group_client
    @instance_client = client_factory.instance_client
    @ami_client = client_factory.ami_client
  end

  def cleanup(remove_key_pairs: false)
    logger.info { "Scanning #{region_code} for running instances..." }
    terminate_instances

    logger.info { "Scanning #{region_code} for available AMIs..." }
    deregister_amis

    logger.info { "Scanning #{region_code} for completed Snapshots..." }
    delete_snapshots

    logger.info { "Scanning #{region_code} for #{@default_security_group} security group..." }
    delete_security_groups

    if remove_key_pairs
      logger.info { "Scanning #{region_code} for key pairs..." }
      delete_key_pairs
    end

    logger.info 'Cleanup Done!'
  end

  private

  def terminate_instances
    instance_client.list.each do |instance|
      next if instance.status == :terminated

      logger.info { "Terminating instance##{instance.id}..." }
      instance_client.terminate(instance_id: instance.id)
      sleep(doze_seconds) until instance_client.terminated?(instance_id: instance.id)
      logger.info { "... instance##{instance.id} terminated" }
    end
  end

  def deregister_amis
    ami_client.select_self_owned(
      ami_name_regexp: Regexp.new(Hailstorm::Model::Helper::AmazonCloudDefaults::AMI_ID)
    ).each do |image|
      next unless image.available?

      logger.info { "Deregistering AMI##{image.id}..." }
      ami_client.deregister(ami_id: image.id)
      logger.info { "... AMI##{image.id} deregistered" }
    end
  end

  def delete_snapshots
    ec2_client.find_self_owned_snapshots.each do |snapshot|
      next unless snapshot.completed?

      logger.info { "Deleting snapshot##{snapshot.id}" }
      ec2_client.delete_snapshot(snapshot_id: snapshot.id)
      logger.info { "... snapshot##{snapshot.id} deleted" }
    end
  end

  def delete_key_pairs
    key_pair_client.list.each do |key_pair|
      key_pair_client.delete(key_pair_id: key_pair.key_pair_id)
      logger.info { "Key pair##{key_pair.key_name} deleted" }
    end
  end

  def delete_security_groups
    security_group_client.list.each do |security_group|
      next unless security_group.group_name == @default_security_group

      security_group_client.delete(group_id: security_group.group_id)
      logger.info { "Security group##{security_group.group_name} deleted" }
    end
  end
end
