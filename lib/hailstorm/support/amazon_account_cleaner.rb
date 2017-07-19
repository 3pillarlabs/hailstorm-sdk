# Standalone script to remove all artifacts associated with an Amazon account -
# Instances, AMI, Snapshots, Key Pairs and Security Groups from every region
# @author Sayantam Dey

require 'aws'
require "hailstorm/support"
require "hailstorm/model/amazon_cloud"
require "hailstorm/behavior/loggable"

class Hailstorm::Support::AmazonAccountCleaner

  include Hailstorm::Behavior::Loggable

  REQUIRED_AWS_KEYS = [:access_key_id, :secret_access_key]

  attr_reader :aws_config

  def initialize(aws_config = {})
    # check arguments
    REQUIRED_AWS_KEYS.each do |key|
      if aws_config[key].blank?
        raise(ArgumentError, ":#{key} needed")
      end
    end
    @aws_config = aws_config.merge(:logger => logger, :max_retries => 3)
    @default_security_group = Hailstorm::Model::AmazonCloud::Defaults::SECURITY_GROUP
  end

  def cleanup(remove_key_pairs = false, given_regions = nil)

    (given_regions || regions).each do |region_code|
      ec2 = ec2_map(region_code)

      logger.info { "Scanning #{region_code} for running instances..." }
      terminate_instances(ec2)

      logger.info { "Scanning #{region_code} for available AMIs..." }
      deregister_amis(ec2)

      logger.info { "Scanning #{region_code} for completed Snapshots..." }
      delete_snapshots(ec2)

      logger.info { "Scanning #{region_code} for #{@default_security_group} security group..." }
      delete_security_groups(ec2)

      if remove_key_pairs
        logger.info { "Scanning #{region_code} for key pairs..." }
        delete_key_pairs(ec2)
      end
    end

    logger.info "Cleanup Done!"
  end

  private

  def regions
    @regions ||= %w(ap-northeast-1 ap-southeast-1 eu-west-1 sa-east-1 us-east-1 us-west-1 us-west-2)
  end

  def ec2_map(region)
    @ec2_map ||= {}
    @ec2_map[region] ||= AWS::EC2.new(aws_config).regions[region]
  end

  def terminate_instances(ec2)
    ec2.instances.each do |instance|
      if instance.status == :running
        logger.info { "Terminating instance##{instance.id}..." }
        instance.terminate()
        sleep(5) until instance.status == :terminated
        logger.info { "... instance##{instance.id} terminated" }
      end
    end
  end

  def deregister_amis(ec2)
    ec2.images().with_owner(:self).each do |image|
      if image.state == :available
        logger.info { "Deregistering AMI##{image.id}..." }
        image.deregister()
        logger.info { "... AMI##{image.id} deregistered" }
      end
    end
  end

  def delete_snapshots(ec2)
    ec2.snapshots.with_owner(:self).each do |snapshot|
      if snapshot.status == :completed
        logger.info { "Deleting snapshot##{snapshot.id}" }
        snapshot.delete()
        logger.info { "... snapshot##{snapshot.id} deleted"}
      end
    end
  end

  def delete_key_pairs(ec2)
    ec2.key_pairs.each do |key_pair|
      key_pair.delete()
      logger.info { "Key pair##{key_pair.name} deleted" }
    end
  end

  def delete_security_groups(ec2)
    ec2.security_groups.each do |security_group|
      if security_group.name == @default_security_group
        security_group.delete()
        logger.info { "Security group##{security_group.name} deleted" }
      end
    end
  end

end