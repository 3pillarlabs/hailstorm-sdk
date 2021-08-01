# frozen_string_literal: true

require 'hailstorm/support'
require 'aws-sdk-ec2'
require 'delegate'
require 'hailstorm/behavior/loggable'
require 'hailstorm/behavior/aws_adaptable'
require 'ostruct'
require 'hailstorm/support/aws_exception_builder'
require 'hailstorm/behavior/aws_exception'

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

  # Proxy for translating Aws library errors to Hailstorm Aws exception
  class ExceptionTranslationProxy

    attr_reader :target

    def initialize(target)
      @target = target
    end

    def method_missing(symbol, *args)
      if target.respond_to?(symbol)
        target.send(symbol, *args)
      else
        super
      end
    rescue Aws::Errors::ServiceError => aws_error
      raise(Hailstorm::Support::AwsExceptionBuilder.from(aws_error))
    end

    def respond_to_missing?(*args)
      target.respond_to?(*args) || super
    end
  end

  # @param [Hash] aws_config(access_key_id, secret_access_key, region, retry_base_delay: 1, retry_limit: 5)
  # @see [Hailstorm::Behavior::AwsAdapterDomain::CLIENT_KEYS] for list of symbols
  def self.clients(aws_config)
    ec2_client = self.ec2_client(aws_config)
    factory_attrs = Hailstorm::Behavior::AwsAdaptable::CLIENT_KEYS.reduce({}) do |attrs, ck|
      client = "#{Hailstorm::Support::AwsAdapter.name}::#{ck.to_s.camelize}".constantize
                                                                            .new(ec2_client: ec2_client)
      attrs.merge(ck.to_sym => ExceptionTranslationProxy.new(client))
    end

    Hailstorm::Behavior::AwsAdaptable::ClientFactory.new(factory_attrs)
  end

  # @param [String] region
  # @param [String] access_key_id
  # @param [String] secret_access_key
  # @param [Float] retry_base_delay
  # @param [Integer] retry_limit
  # @param [Logger] logger
  # @return [Aws::EC2::Client]
  def self.ec2_client(region: nil,
                      access_key_id: nil,
                      secret_access_key: nil,
                      logger: nil,
                      retry_base_delay: DEFAULT_RETRY_BASE_DELAY,
                      retry_limit: DEFAULT_RETRY_LIMIT)

    attrs = { retry_base_delay: retry_base_delay, retry_limit: retry_limit }
    attrs.merge!(logger: logger) unless logger.nil?
    attrs.merge!(region: region) unless region.nil?
    if access_key_id && secret_access_key
      credentials = Aws::Credentials.new(access_key_id, secret_access_key)
      attrs.merge!(credentials: credentials)
    end

    create_raw_ec2_client(attrs)
  end

  # @param [Hash] attrs
  # @return [Aws::EC2::Client]
  # :nodoc:
  def self.create_raw_ec2_client(attrs)
    Aws::EC2::Client.new(attrs)
  end
end
