# frozen_string_literal: true

# AWS security group adapter
class Hailstorm::Support::AwsAdapter::SecurityGroupClient < Hailstorm::Support::AwsAdapter::AbstractClient
  include Hailstorm::Behavior::AwsAdaptable::SecurityGroupClient

  def find(name:, vpc_id: nil, filters: [])
    sg_filters = [{ name: 'group-name', values: [name] }]
    sg_filters.push(name: 'vpc-id', values: [vpc_id]) if vpc_id
    params = { filters: sg_filters }
    add_filters_to_params(filters, params)
    resp = ec2.describe_security_groups(params)
    return if resp.security_groups.empty?

    security_group = resp.security_groups[0]
    sg_attrs = { group_name: security_group.group_name, group_id: security_group.group_id }
    sg_attrs[:vpc_id] = security_group.vpc_id if security_group.respond_to?(:vpc_id)
    Hailstorm::Behavior::AwsAdaptable::SecurityGroup.new(sg_attrs)
  end

  def create(name:, description:, vpc_id: nil)
    params = { group_name: name, description: description, vpc_id: vpc_id }
    resp = ec2.create_security_group(created_tag_specifications('security-group', params))
    Hailstorm::Behavior::AwsAdaptable::SecurityGroup.new(group_id: resp.group_id)
  end

  def authorize_ingress(group_id:, protocol:, port_or_range:, cidr: nil)
    ip_perm = { ip_protocol: protocol.to_s }
    ip_perm[:from_port] = port_or_range.is_a?(Range) ? port_or_range.first : port_or_range
    ip_perm[:to_port] = port_or_range.is_a?(Range) ? port_or_range.last : port_or_range
    ip_perm[:ip_ranges] = [{ cidr_ip: nil }]
    if cidr
      ip_perm[:ip_ranges].first[:cidr_ip] = cidr == :anywhere ? '0.0.0.0/0' : cidr
    else
      ip_perm[:user_id_group_pairs] = [{ group_id: group_id }]
    end

    ec2.authorize_security_group_ingress(group_id: group_id, ip_permissions: [ip_perm])
  end

  def allow_ping(group_id:)
    authorize_ingress(group_id: group_id, protocol: :icmp, port_or_range: -1, cidr: :anywhere)
  end

  def delete(group_id:)
    ec2.delete_security_group(group_id: group_id)
  end

  def list
    ec2.describe_security_groups.security_groups.lazy.map do |sg|
      Hailstorm::Behavior::AwsAdaptable::SecurityGroup.new(sg.to_h.slice(:group_name, :group_id, :vpc_id))
    end
  end
end
