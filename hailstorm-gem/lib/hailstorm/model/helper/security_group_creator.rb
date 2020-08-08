require 'hailstorm/model/helper'
require 'hailstorm/behavior/loggable'
require 'hailstorm/model/helper/security_group_finder'
require 'hailstorm/model/helper/amazon_cloud_defaults'

# Helper method for creating Hailstorm security group
class Hailstorm::Model::Helper::SecurityGroupCreator < Hailstorm::Model::Helper::SecurityGroupFinder
  include Hailstorm::Behavior::Loggable

  attr_reader :security_group_desc, :ssh_port, :security_group_client, :ec2_client, :vpc_subnet_id
  attr_reader :security_group, :region

  # @param [Hailstorm::Behavior::AwsAdaptable::SecurityGroupClient] security_group_client
  # @param [Hailstorm::Behavior::AwsAdaptable::Ec2Client] ec2_client
  # @param [Hailstorm::Model::AmazonCloud] aws_clusterable
  def initialize(security_group_client:, ec2_client:, aws_clusterable:)
    @security_group_client = security_group_client
    @ec2_client = ec2_client
    @vpc_subnet_id = aws_clusterable.vpc_subnet_id
    @ssh_port = aws_clusterable.ssh_port || Hailstorm::Model::Helper::AmazonCloudDefaults::SSH_PORT
    @security_group = aws_clusterable.security_group
    @region = aws_clusterable.region
    @security_group_desc = Hailstorm::Model::Helper::AmazonCloudDefaults::SECURITY_GROUP_DESC
  end

  def create_security_group
    logger.debug { "#{self.class}##{__method__}" }
    vpc_id = find_vpc
    security_group = find_security_group(vpc_id: vpc_id)
    unless security_group
      logger.info("Creating #{self.security_group} security group on #{self.region}...")
      security_group = security_group_client.create(name: self.security_group,
                                                    description: self.security_group_desc,
                                                    vpc_id: vpc_id)

      # allow SSH from anywhere
      port_or_range = self.ssh_port
      security_group_client.authorize_ingress(group_id: security_group.group_id,
                                              protocol: :tcp,
                                              port_or_range: port_or_range,
                                              cidr: :anywhere)

      # allow incoming TCP & UDP to any port within the group
      %i[tcp udp].each do |proto|
        security_group_client.authorize_ingress(group_id: security_group.group_id,
                                                protocol: proto,
                                                port_or_range: 0..65_535)
      end

      security_group_client.allow_ping(group_id: security_group.group_id) # allow ICMP from anywhere
    end

    security_group
  end
end
