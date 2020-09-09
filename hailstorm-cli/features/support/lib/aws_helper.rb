# frozen_string_literal: true

require 'aws-sdk-ec2'
require 'fileutils'

# Methods to access and modify AWS resources.
module AwsHelper

  def aws_keys
    @aws_keys ||= [].tap do |vals|
      require 'yaml'
      key_file_path = File.expand_path('../../../data/keys.yml', __FILE__)
      keys = YAML.load_file(key_file_path)
      vals << keys['access_key']
      vals << keys['secret_key']
    end
  end

  def tagged_instance(tag_value, region = 'us-east-1', status = :running, tag_key = :Name)
    ec2(region).instances
               .select { |instance| instance.state.name.to_sym == status }
               .find do |instance|
      instance.tags
              .find { |tag| tag.key.to_sym == tag_key }.value =~ Regexp.new(tag_value, Regexp::IGNORECASE)
    end
  end

  def write_site_server_url(server_name)
    FileUtils.mkdir_p(File.dirname(site_server_url_path))
    File.open(site_server_url_path, 'w') do |file|
      file.print(server_name)
    end
  end

  def site_server_url_path
    File.join(tmp_path, 'site_server.txt')
  end

  # Deletes the all resources in the VPC provided it has not drifted from the configuration set by an
  # earlier invocation of this integration suite.
  # Order of deletion - route_table_association, route_table, igw, subnet, hailstorm security_group, vpc
  def delete_vpc_if_exists(vpc_name, region)
    vpc = find_powered_off_vpc(vpc_name, region)
    return unless vpc

    vpc_res_group = zero_drift_resources(vpc_name, vpc)
    route_tables = vpc_res_group.route_tables
    subnets = vpc_res_group.subnets
    internet_gateways = vpc_res_group.internet_gateways

    subnet = subnets.first
    disassociate_route_table(subnet, route_tables)

    igw = internet_gateways.first
    disassociate_igw(igw, vpc) if igw

    subnet&.delete

    vpc.security_groups.select { |sg| sg.group_name == 'Hailstorm' }.each(&:delete)

    vpc.delete
  end

  private

  def disassociate_igw(igw, vpc)
    igw.detach_from_vpc(vpc_id: vpc.vpc_id)
    igw.delete
  end

  def ec2(region)
    config = { region: region }
    config[:access_key_id], config[:secret_access_key] = aws_keys
    ec2_client = Aws::EC2::Client.new(config)
    Aws::EC2::Resource.new(client: ec2_client)
  end

  # A powered off VPC is a VPC without running instances
  def find_powered_off_vpc(vpc_name, region)
    vpc = ec2(region).vpcs(filters: [{ name: 'tag:Name', values: [vpc_name] }]).first
    return unless vpc

    raise("#{vpc_name} VPC has instances running/stopped, terminate first") unless vpc.instances.to_a.empty?

    vpc
  end

  def zero_drift_resources(vpc_name, vpc)
    route_tables = vpc.route_tables.to_a
    raise("#{vpc_name} VPC drifted - more than one route table") if route_tables.size > 1

    subnets = vpc.subnets.to_a
    raise("#{vpc_name} VPC drifted - more than one subnet") if subnets.size > 1

    internet_gateways = vpc.internet_gateways.to_a
    raise("#{vpc_name} VPC drifted - more than one internet gateway") if internet_gateways.size > 1

    Struct.new('VpcResourceGroup', :route_tables, :subnets, :internet_gateways)
    Struct::VpcResourceGroup.new(route_tables, subnets, internet_gateways)
  end

  def disassociate_route_table(subnet, route_tables)
    route_table = route_tables.first
    return unless route_table

    route_table.routes.reject { |route| route.gateway_id == 'local' }.each(&:delete)
    route_table.associations.find { |assoc| assoc.subnet_id == subnet.subnet_id } if subnet
  end
end

World(AwsHelper)
