# frozen_string_literal: true

require 'hailstorm/support/aws_adapter'

# Abstract class for all client adapters.
class Hailstorm::Support::AwsAdapter::AbstractClient
  include Hailstorm::Behavior::Loggable
  include Hailstorm::Behavior::AwsAdaptable::Taggable

  # @return [Aws::EC2::Client]
  attr_reader :ec2

  # @param [Aws::EC2::Client] ec2_client
  def initialize(ec2_client:)
    @ec2 = ec2_client
  end

  # @param [String] resource_id
  # @param [String] name
  def tag_name(resource_id:, name:)
    tag_resource(resource_id, key: 'Name', value: name)
  end

  # @param [String] resource_id
  # @param [String] key
  # @param [Object] value
  def tag_resource(resource_id, key:, value:)
    ec2.create_tags(resources: [resource_id], tags: [{ key: key, value: value.to_s }])
  end

  CREATED_TAG = { key: 'hailstorm:created', value: true.to_s }.freeze
  CREATED_FILTER = { name: "tag:#{CREATED_TAG[:key]}", values: [CREATED_TAG[:value]] }.freeze

  protected

  # Iterates through filters and adds to params[:filters] (mutates params).
  # :filters key is initialized to an Array if not present in params and filters is not empty.
  # If filters is empty, params is not mutated.
  def add_filters_to_params(filters, params)
    return if filters.empty?

    params[:filters] ||= []
    filters.each_with_object(params[:filters]) do |filter, object|
      object << filter if filter.is_a?(Hash)
      object << CREATED_FILTER if filter == :created
    end
  end

  # @param [String] resource_type
  # @param [Hash, NilClass] params
  # @return [Hash]
  def created_tag_specifications(resource_type, params = nil)
    tag_spec = {
      tag_specifications: [{
        resource_type: resource_type,
        tags: [CREATED_TAG]
      }]
    }

    params ? params.merge(tag_spec) : tag_spec
  end

  # @return [Hash]
  def created_tag
    CREATED_TAG
  end
end
