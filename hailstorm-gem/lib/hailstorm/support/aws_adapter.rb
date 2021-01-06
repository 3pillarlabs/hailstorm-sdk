# frozen_string_literal: true

require 'hailstorm/support'
require 'aws-sdk-ec2'
require 'delegate'
require 'hailstorm/behavior/loggable'
require 'hailstorm/behavior/aws_adaptable'
require 'ostruct'
require 'hailstorm/support/aws_adapter_clients/aws_exception'

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

  DEFAULT_RETRY_BASE_DELAY = 1.0
  DEFAULT_RETRY_LIMIT = 5


  class ExceptionTranslationProxy

    attr_reader :target

    def initialize(target)
      @target = target
    end

    def method_missing(symbol, *args)
      target.send(symbol, *args)
    rescue Aws::Errors::ServiceError => aws_error
      raise(Hailstorm::AwsException.from(aws_error))
    end

    def respond_to_missing?(*args)
      target.respond_to?(*args)
    end
  end

  # @param [Hash] aws_config(access_key_id, secret_access_key, region, retry_base_delay: 1, retry_limit: 5)
  def self.clients(aws_config)
    unless @clients
      credentials = Aws::Credentials.new(aws_config[:access_key_id], aws_config[:secret_access_key])
      ec2_client = Aws::EC2::Client.new(region: aws_config[:region],
                                        credentials: credentials,
                                        retry_base_delay: aws_config[:retry_base_delay] || DEFAULT_RETRY_BASE_DELAY,
                                        retry_limit: aws_config[:retry_limit] || DEFAULT_RETRY_LIMIT)
      factory_attrs = Hailstorm::Behavior::AwsAdaptable::CLIENT_KEYS.reduce({}) do |attrs, ck|
        client = "#{Hailstorm::Support::AwsAdapter.name}::#{ck.to_s.camelize}".constantize
                                                                              .new(ec2_client: ec2_client)
        attrs.merge(ck.to_sym => ExceptionTranslationProxy.new(client))
      end

      @clients = Hailstorm::Behavior::AwsAdaptable::ClientFactory.new(factory_attrs)
    end

    @clients
  end
end
