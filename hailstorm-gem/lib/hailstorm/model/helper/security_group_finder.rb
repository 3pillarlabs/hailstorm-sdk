require 'hailstorm/model/helper'
require 'hailstorm/behavior/loggable'

# Finds an EC2 Security Group
class Hailstorm::Model::Helper::SecurityGroupFinder
  include Hailstorm::Behavior::Loggable

  attr_reader :ec2_client, :security_group_client, :vpc_subnet_id, :security_group

  # @param [Hailstorm::Behavior::AwsAdaptable::Ec2Client] ec2_client
  # @param [Hailstorm::Behavior::AwsAdaptable::SecurityGroupClient] security_group_client
  # @param [String] vpc_subnet_id
  # @param [String] security_group security group name tag
  def initialize(ec2_client: nil, security_group_client:, vpc_subnet_id: nil, security_group:)
    raise(ArgumentError, 'ec2_client needed if vpc_subnet_id provided') if vpc_subnet_id && !ec2_client

    @ec2_client = ec2_client
    @security_group_client = security_group_client
    @vpc_subnet_id = vpc_subnet_id
    @security_group = security_group
  end

  def find_security_group(vpc_id: nil)
    vpc_id ||= find_vpc
    security_group_client.find(name: self.security_group, vpc_id: vpc_id)
  end

  protected

  def find_vpc
    ec2_client.find_vpc(subnet_id: self.vpc_subnet_id) if self.vpc_subnet_id
  end
end
