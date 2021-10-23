# frozen_string_literal: true

# Methods for AWS VPC resource usage
module AwsVpcHelper

  def select_public_subnets(region:)
    route_tables = ec2_resource(region: region).vpcs
                                               .flat_map { |vpc| vpc.route_tables.to_a }

    subnets = find_igw_subnets(route_tables)
    subnets = find_main_rtb_subnets(route_tables) if subnets.empty?
    subnets.select(&:map_public_ip_on_launch)
  end

  def route_table_contains_igw?(route_table)
    !fetch_routes(route_table).find { |route| route && route.gateway_id != 'local' }.nil?
  end

  def fetch_routes(route_table)
    route_table.routes
  rescue Aws::Errors::ServiceError, ArgumentError
    []
  end

  def find_main_rtb_subnets(route_tables)
    route_tables.flat_map { |route_table| route_table.associations.to_a }
                .select(&:main)
                .map(&:route_table)
                .map(&:vpc)
                .flat_map { |vpc| vpc.subnets.to_a }
  end

  def find_igw_subnets(route_tables)
    route_tables.select { |route_table| route_table_contains_igw?(route_table) }
                .flat_map { |route_table| route_table.associations.to_a }
                .select(&:subnet_id)
                .map(&:subnet)
  end

  # @param [String] region
  # @param [Hash] tags
  # @return Enumerable<Aws::EC2::Subnet>
  def tagged_subnets(region:, tags:)
    ec2 = ec2_resource(region: region)
    ec2.subnets(filters: to_tag_filters(tags)).to_a
  end

  # @param [String] region
  # @param [Hash] tags
  # @return Enumerable<Aws::EC2::Vpc>
  def tagged_vpcs(region:, tags:)
    ec2 = ec2_resource(region: region)
    ec2.vpcs(filters: to_tag_filters(tags)).to_a
  end

  # @param [String] region
  # @param [Hash] tags
  # @return Enumerable<Aws::EC2::InternetGateway>
  def tagged_internet_gws(region:, tags:)
    ec2 = ec2_resource(region: region)
    ec2.internet_gateways(filters: to_tag_filters(tags)).to_a
  end
end
