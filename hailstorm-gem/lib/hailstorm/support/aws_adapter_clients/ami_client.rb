# frozen_string_literal: true

# EC2 Image (AMI) adapter
class Hailstorm::Support::AwsAdapter::AmiClient < Hailstorm::Support::AwsAdapter::AbstractClient
  include Hailstorm::Behavior::AwsAdaptable::AmiClient

  def find_self_owned(ami_name_regexp:)
    select_self_owned(ami_name_regexp: ami_name_regexp).first
  end

  # @param [Aws::EC2::Types::Image] ami
  # @return [Hailstorm::Behavior::AwsAdaptable::Ami]
  def decorate(ami)
    state_reason = if ami.state_reason
                     Hailstorm::Behavior::AwsAdaptable::StateReason.new(code: ami.state_reason.code,
                                                                        message: ami.state_reason.message)
                   end
    ebs_mapping = ami.block_device_mappings.select { |device| device.ebs&.snapshot_id }.first
    snapshot_id = ebs_mapping.ebs.snapshot_id if ebs_mapping
    Hailstorm::Behavior::AwsAdaptable::Ami.new(image_id: ami.image_id,
                                               name: ami.name,
                                               state: ami.state,
                                               state_reason: state_reason,
                                               snapshot_id: snapshot_id)
  end
  private :decorate

  # @see Hailstorm::Behavior::AwsAdaptable::AmiClient#available?
  def available?(ami_id:)
    ami = find(ami_id: ami_id)
    ami&.available?
  end

  # @see Hailstorm::Behavior::AwsAdaptable::AmiClient#register_ami
  def register_ami(name:, instance_id:, description:)
    params = { name: name, instance_id: instance_id, description: description }
    resp = ec2.create_image(params)
    tag_resource(resp.image_id, created_tag)
    resp.image_id
  end

  def deregister(ami_id:)
    ec2.deregister_image(image_id: ami_id)
  end

  def find(ami_id:, filters: [])
    params = { image_ids: [ami_id] }
    add_filters_to_params(filters, params)
    resp = ec2.describe_images(params)
    return nil if resp.images.empty?

    decorate(resp.images[0])
  end

  def select_self_owned(ami_name_regexp:)
    ec2.describe_images(owners: [:self.to_s])
       .images
       .select { |ami| ami.state.to_sym == :available && ami_name_regexp.match(ami.name) }
       .map { |ami| decorate(ami) }
  end
end
