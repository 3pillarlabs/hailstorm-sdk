# frozen_string_literal: true

require 'hailstorm/model/helper'
require 'hailstorm/behavior/loggable'

# Helper for SSH identity
class Hailstorm::Model::Helper::AwsIdentityHelper
  include Hailstorm::Behavior::Loggable

  attr_reader :identity_file_path, :ssh_identity, :key_pair_client

  def initialize(identity_file_path:, ssh_identity:, key_pair_client:)
    @identity_file_path = identity_file_path
    @ssh_identity = ssh_identity
    @key_pair_client = key_pair_client
  end

  # If the `identity_file_path` does not exist, delete the existing key pair, and
  # create a new one.
  def validate_or_create_identity
    return if File.exist?(identity_file_path)

    key_pair_id = key_pair_client.find(name: self.ssh_identity)
    if key_pair_id
      key_pair_client.delete(key_pair_id: key_pair_id)
      logger.warn("Unusable key_pair '#{key_pair_id}' was deleted")
    end

    create_key_pair
  end

  private

  def create_key_pair
    logger.debug { "Creating #{self.ssh_identity} key_pair..." }
    key_pair = key_pair_client.create(name: self.ssh_identity)
    File.open(identity_file_path, 'w') do |file|
      file.print(key_pair.private_key)
    end

    secure_identity_file(identity_file_path)
  end

  # Sets read only permissions for owner of identity file
  def secure_identity_file(file_path)
    File.chmod(0o400, file_path)
  end
end
