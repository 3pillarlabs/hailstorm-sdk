require 'hailstorm/support'
require 'hailstorm/model/amazon_cloud'
require 'hailstorm/behavior/loggable'

# Standalone script to remove all artifacts associated with an Amazon account -
# Instances, AMI, Snapshots, Key Pairs and Security Groups from every region
# @author Sayantam Dey
class Hailstorm::Support::AmazonAccountCleaner
  include Hailstorm::Behavior::Loggable

  attr_reader :aws_config, :doze_seconds

  def initialize(access_key_id:, secret_access_key:, max_retries: 3, doze_seconds: 5)
    @aws_config = {
      access_key_id: access_key_id,
      secret_access_key: secret_access_key
    }.merge(logger: logger, max_retries: max_retries)

    @doze_seconds = doze_seconds
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

    logger.info 'Cleanup Done!'
  end

  private

  def regions
    @regions ||= %w[ap-northeast-1 ap-southeast-1 eu-west-1 sa-east-1 us-east-1 us-west-1 us-west-2]
  end

  def ec2_map(region)
    @ec2_map ||= {}
    @ec2_map[region] ||= ec2_adapter(aws_config.merge(region: region))
  end

  # @param [Hash] attrs
  # @return [Hailstorm::Support::AwsAdapter::EC2]
  def ec2_adapter(attrs)
    Hailstorm::Support::AwsAdapter::EC2.new(attrs)
  end

  def terminate_instances(ec2)
    ec2.all_instances.each do |instance|
      next if instance.status == :terminated

      logger.info { "Terminating instance##{instance.id}..." }
      instance.terminate
      sleep(doze_seconds) until instance.status == :terminated
      logger.info { "... instance##{instance.id} terminated" }
    end
  end

  def deregister_amis(ec2)
    ec2.find_self_owned_ami(regexp: Regexp.new(Hailstorm::Model::AmazonCloud::Defaults::AMI_ID)).each do |image|
      next unless image.state == :available

      logger.info { "Deregistering AMI##{image.id}..." }
      image.deregister
      logger.info { "... AMI##{image.id} deregistered" }
    end
  end

  def delete_snapshots(ec2)
    ec2.find_self_owned_snapshots.each do |snapshot|
      next unless snapshot.status == :completed

      logger.info { "Deleting snapshot##{snapshot.id}" }
      snapshot.delete
      logger.info { "... snapshot##{snapshot.id} deleted" }
    end
  end

  def delete_key_pairs(ec2)
    ec2.all_key_pairs.each do |key_pair|
      key_pair.delete
      logger.info { "Key pair##{key_pair.name} deleted" }
    end
  end

  def delete_security_groups(ec2)
    ec2.all_security_groups.each do |security_group|
      next unless security_group.name == @default_security_group

      security_group.delete
      logger.info { "Security group##{security_group.name} deleted" }
    end
  end
end
