# frozen_string_literal: true

# VPC adapter
class Hailstorm::Support::AwsAdapter::VpcClient < Hailstorm::Support::AwsAdapter::AbstractClient
  include Hailstorm::Behavior::AwsAdaptable::VpcClient

  def create(cidr:)
    resp = ec2.create_vpc(created_tag_specifications('vpc', cidr_block: cidr))
    resp.vpc.vpc_id
  end

  def modify_attribute(vpc_id:, **kwargs)
    ec2.modify_vpc_attribute(kwargs.transform_values { |v| { value: v } }.merge(vpc_id: vpc_id))
  end

  def available?(vpc_id:)
    vpc = find(vpc_id: vpc_id)
    vpc&.available?
  end

  def find(vpc_id:, filters: [])
    params = { vpc_ids: [vpc_id] }
    add_filters_to_params(filters, params)
    resp = ec2.describe_vpcs(params)
    return if resp.vpcs.empty?

    vpc = resp.vpcs.first
    Hailstorm::Behavior::AwsAdaptable::Vpc.new(vpc_id: vpc.vpc_id, state: vpc.state)
  end

  def delete(vpc_id:)
    ec2.delete_vpc(vpc_id: vpc_id)
  end
end
