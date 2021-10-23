# frozen_string_literal: true

require 'aws-sdk-ec2'

require_relative './aws_ec2_helper'
require_relative './aws_vpc_helper'
require_relative './aws_security_group_helper'

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

  # Converts a 1-level hash to an array of AWS tags.
  #   > to_tag_array(hailstorm: {project: 'abc', created: true})
  #   > [{name: 'hailstorm:project', values: ['abc']}, {name: 'hailstorm:created', values: ['true']}]
  # @param [Hash] tags
  # @return [Array<Hash>]
  def to_tag_filters(tags)
    key_namespace = tags.keys.first
    return [] if key_namespace.nil?

    tags[key_namespace].map do |key, value|
      { name: "tag:#{key_namespace}:#{key}", values: [value.to_s] }
    end
  end

  include AwsEc2Helper
  include AwsVpcHelper
  include AwsSecurityGroupHelper
end

World(AwsHelper)
