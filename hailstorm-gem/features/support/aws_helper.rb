# frozen_string_literal: true

require 'aws-sdk-ec2'

# Methods for AWS resource usage
module AwsHelper

  def aws_keys
    @aws_keys ||= [].tap do |vals|
      require 'yaml'
      key_file_path = File.expand_path('../../data/keys.yml', __FILE__)
      keys = YAML.load_file(key_file_path)
      vals << keys['access_key']
      vals << keys['secret_key']
    end
  end

  def ec2_resource(region:)
    ec2_client = Aws::EC2::Client.new(
      region: region,
      credentials: Aws::Credentials.new(*aws_keys)
    )

    Aws::EC2::Resource.new(client: ec2_client)
  end

  def select_public_subnets(region:)
    route_tables = ec2_resource(region: region).vpcs
                                               .flat_map { |vpc| vpc.route_tables.to_a }

    subnets = route_tables.select { |route_table| route_table_contains_igw?(route_table) }
                          .flat_map { |route_table| route_table.associations.to_a }
                          .select(&:subnet_id)
                          .map(&:subnet)

    if subnets.empty?
      subnets = route_tables.flat_map { |route_table| route_table.associations.to_a }
                            .select(&:main)
                            .map(&:route_table)
                            .map(&:vpc)
                            .flat_map { |vpc| vpc.subnets.to_a }
    end

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

  def terminate_agents(region, *load_agents)
    ec2 = ec2_resource(region: region)
    load_agents.each do |agent|
      ec2_instance = ec2.instances(instance_ids: [agent.identifier]).first
      ec2_instance&.terminate
    end
  end
end
