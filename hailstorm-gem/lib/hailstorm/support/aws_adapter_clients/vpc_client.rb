# frozen_string_literal: true

# VPC adapter
class Hailstorm::Support::AwsAdapter::VpcClient < Hailstorm::Support::AwsAdapter::AbstractClient
  include Hailstorm::Behavior::AwsAdaptable::VpcClient

  def create(cidr:)
    resp = ec2.create_vpc(cidr_block: cidr)
    resp.vpc.vpc_id
  end

  def modify_attribute(vpc_id:, **kwargs)
    ec2.modify_vpc_attribute(kwargs.transform_values { |v| { value: v } }.merge(vpc_id: vpc_id))
  end

  def available?(vpc_id:)
    resp = ec2.describe_vpcs(vpc_ids: [vpc_id])
    !resp.vpcs.blank? && resp.vpcs[0].state.to_sym == :available
  end
end
