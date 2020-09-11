# frozen_string_literal: true

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

  def tag_name(resource_id:, name:)
    ec2.create_tags(resources: [resource_id], tags: [{ key: 'Name', value: name }])
  end
end
