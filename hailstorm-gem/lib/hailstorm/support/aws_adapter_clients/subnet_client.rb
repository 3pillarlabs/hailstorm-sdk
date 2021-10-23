# frozen_string_literal: true

# Subnet adapter
class Hailstorm::Support::AwsAdapter::SubnetClient < Hailstorm::Support::AwsAdapter::AbstractClient
  include Hailstorm::Behavior::AwsAdaptable::SubnetClient

  def available?(subnet_id:)
    resp = query(subnet_id: subnet_id)
    !resp.subnets.blank? && resp.subnets[0].state.to_sym == :available
  end

  def create(vpc_id:, cidr:)
    resp = ec2.create_subnet(created_tag_specifications('subnet', cidr_block: cidr, vpc_id: vpc_id))
    resp.subnet.subnet_id
  end

  def find(subnet_id: nil, name_tag: nil, filters: [])
    params = { subnet_id: subnet_id, name_tag: name_tag }
    add_filters_to_params(filters, params)
    resp = query(params)
    return nil if resp.subnets.empty?

    resp.subnets[0].subnet_id
  end

  def modify_attribute(subnet_id:, **kwargs)
    attrs = kwargs.reduce({}) { |s, e| s.merge(e.first => { value: e.last }) }
    attrs[:subnet_id] = subnet_id
    ec2.modify_subnet_attribute(attrs)
  end

  def delete(subnet_id:)
    ec2.delete_subnet(subnet_id: subnet_id)
  end

  def find_vpc(subnet_id:)
    resp = ec2.describe_subnets(subnet_ids: [subnet_id])
    return nil if resp.subnets.empty?

    resp.subnets[0].vpc_id
  end

  private

  def query(subnet_id: nil, name_tag: nil, filters: [])
    params = {}
    params[:subnet_ids] = [subnet_id] if subnet_id
    params[:filters] = filters unless filters.blank?
    if name_tag
      params[:filters] = [] unless params.key?(:filters)
      params[:filters].push(name: 'tag:Name', values: [name_tag])
    end

    ec2.describe_subnets(params)
  end
end
