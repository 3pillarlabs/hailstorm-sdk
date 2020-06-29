require 'aws-sdk-ec2'

module AwsHelper

  def aws_keys
    @keys ||= [].tap {|vals|
      require 'yaml'
      key_file_path = File.expand_path('../../data/keys.yml', __FILE__)
      keys = YAML.load_file(key_file_path)
      vals << keys['access_key']
      vals << keys['secret_key']
    }
  end

  def ec2_resource(region:)
    ec2_client = Aws::EC2::Client.new(
      region: region,
      credentials: Aws::Credentials.new(*aws_keys)
    )

    Aws::EC2::Resource.new(client: ec2_client)
  end

  def select_public_subnets(region:)
    ec2_resource(region: region)
      .vpcs
      .flat_map { |vpc| vpc.route_tables.to_a }
      .select { |route_table| (route_table.routes rescue []).find { |route| route && route.gateway_id != 'local' } }
      .flat_map { |route_table| route_table.associations.to_a }
      .select { |assoc| assoc.subnet_id }
      .map { |assoc| assoc.subnet }
      .select { |subnet| subnet.map_public_ip_on_launch }
  end
end
