require 'hailstorm/model/helper'
require 'hailstorm/support/waiter'
require 'hailstorm/behavior/loggable'

# Create VPC and associated infrastructure
class Hailstorm::Model::Helper::VpcHelper
  include Hailstorm::Behavior::Loggable
  include Hailstorm::Support::Waiter

  attr_reader :vpc_client, :subnet_client, :internet_gateway_client, :route_table_client

  def initialize(vpc_client:, subnet_client:, internet_gateway_client:, route_table_client:)
    @vpc_client = vpc_client
    @subnet_client = subnet_client
    @internet_gateway_client = internet_gateway_client
    @route_table_client = route_table_client
  end

  # @param [String] subnet_name_tag
  # @param [String] vpc_name_tag
  # @param [String] cidr
  def find_or_create_vpc_subnet(subnet_name_tag:, vpc_name_tag:, cidr:)
    subnet_client.find(name_tag: subnet_name_tag) || create_hailstorm_subnet(subnet_name: subnet_name_tag,
                                                                             vpc_name: vpc_name_tag,
                                                                             cidr: cidr)
  end

  private

  # https://docs.aws.amazon.com/vpc/latest/userguide/vpc-subnets-commands-example.html
  # @return [String] subnet_id
  # @param [String] vpc_name
  # @param [String] cidr
  def create_hailstorm_subnet(subnet_name:, vpc_name:, cidr:)
    created_vpc_id = create_hailstorm_vpc(vpc_name: vpc_name, cidr: cidr)
    hailstorm_subnet_id = subnet_client.create(vpc_id: created_vpc_id, cidr: cidr)
    wait_for("#{subnet_name} to be available") { subnet_client.available?(subnet_id: hailstorm_subnet_id) }

    subnet_client.tag_name(resource_id: hailstorm_subnet_id, name: subnet_name)
    subnet_client.modify_attribute(subnet_id: hailstorm_subnet_id, map_public_ip_on_launch: true)
    logger.info { "Created #{subnet_name} subnet - #{hailstorm_subnet_id}" }
    make_subnet_public(vpc_id: created_vpc_id, subnet_id: hailstorm_subnet_id, vpc_name: vpc_name)
    hailstorm_subnet_id
  end

  # @return [String] vpc_id
  # @param [String] cidr
  def create_hailstorm_vpc(vpc_name:, cidr:)
    vpc_tag_name = "#{vpc_name}_#{Hailstorm.env}"
    hailstorm_vpc_id = vpc_client.create(cidr: cidr)
    wait_for("#{vpc_tag_name} VPC to be available") { vpc_client.available?(vpc_id: hailstorm_vpc_id) }

    vpc_client.modify_attribute(vpc_id: hailstorm_vpc_id, enable_dns_support: true)
    vpc_client.modify_attribute(vpc_id: hailstorm_vpc_id, enable_dns_hostnames: true)
    vpc_client.tag_name(resource_id: hailstorm_vpc_id, name: vpc_tag_name)
    logger.info { "Created #{vpc_tag_name} VPC - #{hailstorm_vpc_id}" }
    hailstorm_vpc_id
  end

  # @param [String] vpc_id
  # @param [String] subnet_id
  # @param [String] vpc_name
  def make_subnet_public(vpc_id:, subnet_id:, vpc_name:)
    igw_id = internet_gateway_client.create
    internet_gateway_client.tag_name(resource_id: igw_id, name: vpc_name)
    internet_gateway_client.attach(igw_id: igw_id, vpc_id: vpc_id)
    logger.info { "Created Internet Gateway #{igw_id}" }

    route_table_id = route_table_client.main_route_table(vpc_id: vpc_id) || route_table_client.create(vpc_id: vpc_id)
    route_table_client.create_route(route_table_id: route_table_id, cidr: '0.0.0.0/0', internet_gateway_id: igw_id)
    wait_for("Route table #{route_table_id} default route to be created") do
      route_table_client.routes(route_table_id: route_table_id).all?(&:active?)
    end

    route_table_client.associate_with_subnet(route_table_id: route_table_id, subnet_id: subnet_id)
    logger.info { "Created routing table with default route #{route_table_id}" }
  end
end
