# frozen_string_literal: true

# AWS KeyPair adapter
class Hailstorm::Support::AwsAdapter::KeyPairClient < Hailstorm::Support::AwsAdapter::AbstractClient
  include Hailstorm::Behavior::AwsAdaptable::KeyPairClient
  include Hailstorm::Behavior::Loggable

  def find(name:)
    resp = ec2.describe_key_pairs(key_names: [name])
    key_pair_info = resp.to_h[:key_pairs].first
    key_pair_info[:key_pair_id] if key_pair_info
  rescue Aws::EC2::Errors::InvalidKeyPairNotFound => not_found
    logger.warn(not_found.message)
    nil # XXX: do not remove this nil statement until a failing test can be created without it
  end

  def delete(key_pair_id:)
    ec2.delete_key_pair(key_pair_id: key_pair_id)
  end

  def create(name:)
    resp = ec2.create_key_pair(created_tag_specifications('key-pair', key_name: name))
    attribute_keys = %i[key_fingerprint key_material key_name key_pair_id]
    Hailstorm::Behavior::AwsAdaptable::KeyPair.new(resp.to_h.slice(*attribute_keys))
  end

  def list
    ec2.describe_key_pairs.key_pairs.lazy.map do |key_pair|
      Hailstorm::Behavior::AwsAdaptable::KeyPairInfo.new(key_pair.to_h)
    end
  end
end
