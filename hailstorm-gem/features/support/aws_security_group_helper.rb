# frozen_string_literal: true

# Methods for AWS Security Group resource usage
module AwsSecurityGroupHelper

  # @param [String] region
  # @param [String] group_name
  # @param [String] vpc_id
  # @return [Aws::EC2::SecurityGroup]
  def create_security_group(region:, group_name:, vpc_id:)
    security_group = search_security_groups(region: region, group_name: group_name, vpc_id: vpc_id).to_a.first
    return security_group if security_group

    ec2 = ec2_resource(region: region)
    ec2.create_security_group(group_name: group_name, description: group_name, vpc_id: vpc_id)
  end

  # @param [String] region
  # @param [String] security_group_id
  # @return [Boolean]
  # @param [String, nil] group_name
  # @param [String, nil] vpc_id
  def security_group_exists?(region:, security_group_id: nil, group_name: nil, vpc_id: nil)
    search_security_groups(
      region: region,
      security_group_id: security_group_id,
      group_name: group_name,
      vpc_id: vpc_id
    ).to_a.empty? == false
  end

  # @param [String] region
  # @param [String, nil] security_group_id
  # @param [String, nil] group_name
  # @param [String, nil] vpc_id
  # @return [Aws::EC2::SecurityGroup::Collection]
  def search_security_groups(region:, security_group_id: nil, group_name: nil, vpc_id: nil)
    ec2 = ec2_resource(region: region)
    params = {}
    params[:group_ids] = [security_group_id] if security_group_id
    params[:filters] = [] if group_name || vpc_id
    params[:filters].push({ name: 'vpc-id', values: [vpc_id] }) if vpc_id
    params[:filters].push({ name: 'group-name', values: [group_name] }) if group_name
    ec2.security_groups(params)
  end

  # @param [String] region
  # @param [Hash] tags
  # @return Enumerable<Aws::EC2::SecurityGroup>
  def tagged_security_groups(region:, tags:)
    ec2 = ec2_resource(region: region)
    ec2.security_groups(filters: to_tag_filters(tags)).to_a
  end
end
