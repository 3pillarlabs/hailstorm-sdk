# frozen_string_literal: true

# Internet Gateway Client adapter
class Hailstorm::Support::AwsAdapter::InternetGatewayClient < Hailstorm::Support::AwsAdapter::AbstractClient
  include Hailstorm::Behavior::AwsAdaptable::InternetGatewayClient

  def attach(igw_id:, vpc_id:)
    ec2.attach_internet_gateway(internet_gateway_id: igw_id, vpc_id: vpc_id)
  end

  def create
    resp = ec2.create_internet_gateway(created_tag_specifications('internet-gateway'))
    resp.internet_gateway.internet_gateway_id
  end

  def select(vpc_id:, filters: [])
    params = { filters: [{ name: 'attachment.vpc-id', values: [vpc_id] }] }
    add_filters_to_params(filters, params)
    ec2.describe_internet_gateways(params)
       .internet_gateways
       .map { |igw| Hailstorm::Behavior::AwsAdaptable::InternetGateway.new(id: igw.internet_gateway_id) }
  end

  def delete(igw_id:)
    ec2.delete_internet_gateway(internet_gateway_id: igw_id)
  end

  def detach_from_vpc(igw_id:, vpc_id:)
    ec2.detach_internet_gateway(internet_gateway_id: igw_id, vpc_id: vpc_id)
  end
end
