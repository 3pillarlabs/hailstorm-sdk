require 'hailstorm/support'
require 'aws-sdk-ec2'
require 'delegate'
require 'hailstorm/behavior/loggable'
require 'hailstorm/behavior/aws_adaptable'
require 'ostruct'

# AWS SDK adapter.
# Route all calls to AWS SDK through this adapter.
class Hailstorm::Support::AwsAdapter
  include Hailstorm::Behavior::Loggable

  load 'hailstorm/support/aws_adapter_clients/abstract_client.rb'
  load 'hailstorm/support/aws_adapter_clients/ec2_client.rb'
  load 'hailstorm/support/aws_adapter_clients/key_pair_client.rb'
  load 'hailstorm/support/aws_adapter_clients/instance_client.rb'
  load 'hailstorm/support/aws_adapter_clients/security_group_client.rb'
  load 'hailstorm/support/aws_adapter_clients/ami_client.rb'
  load 'hailstorm/support/aws_adapter_clients/subnet_client.rb'
  load 'hailstorm/support/aws_adapter_clients/vpc_client.rb'
  load 'hailstorm/support/aws_adapter_clients/internet_gateway_client.rb'
  load 'hailstorm/support/aws_adapter_clients/route_table_client.rb'

  # @param [Hash] aws_config(access_key_id secret_access_key region)
  def self.clients(aws_config)
    unless @clients
      credentials = Aws::Credentials.new(aws_config[:access_key_id], aws_config[:secret_access_key])
      ec2_client = Aws::EC2::Client.new(region: aws_config[:region], credentials: credentials)
      factory_attrs = Hailstorm::Behavior::AwsAdaptable::CLIENT_KEYS.reduce({}) do |attrs, ck|
        attrs.merge(
          ck.to_sym => "#{Hailstorm::Support::AwsAdapter.name}::#{ck.to_s.camelize}".constantize
                                                                                    .new(ec2_client: ec2_client)
        )
      end

      @clients = Hailstorm::Behavior::AwsAdaptable::ClientFactory.new(factory_attrs)
    end

    @clients
  end
end
