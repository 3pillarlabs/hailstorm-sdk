# frozen_string_literal: true

require 'hailstorm/model/helper'
require 'hailstorm/behavior/sshable'

# AmazonCloud default settings
class Hailstorm::Model::Helper::AmazonCloudDefaults
  AMI_ID              = '3pg-hailstorm'
  SECURITY_GROUP      = 'Hailstorm'
  SECURITY_GROUP_DESC = 'Allows SSH traffic from anywhere and all internal TCP, UDP and ICMP traffic'
  SSH_USER            = 'ubuntu'
  SSH_IDENTITY        = 'hailstorm'
  INSTANCE_TYPE       = 'm5a.large'
  INSTANCE_CLASS_SCALE_FACTOR = { t2: 2, t3: 2, t3a: 2, m4: 4, m5: 5,
                                  m5a: 6, m5ad: 7, m5d: 8, m5dn: 9, m5n: 10 }.freeze
  INSTANCE_TYPE_SCALE_FACTOR = 2
  KNOWN_INSTANCE_TYPES = [:nano, :micro, :small, :medium, :large, :xlarge,
                          '2xlarge'.to_sym, '4xlarge'.to_sym, '8xlarge'.to_sym, '10xlarge'.to_sym, '12xlarge'.to_sym,
                          '16xlarge'.to_sym, '24xlarge'.to_sym, :metal].freeze

  MIN_THREADS_ONE_AGENT = 10
  SSH_PORT = Hailstorm::Behavior::SSHable::Defaults::SSH_PORT
  EC2_REGION = 'us-east-1'
  VPC_NAME = 'hailstorm'
  CIDR_BLOCK = '10.0.0.0/16'
  SUBNET_NAME = "#{VPC_NAME} public"

  # @param [String] instance_type
  # @return [Integer]
  def self.calc_max_threads_per_instance(instance_type:)
    iclass, itype = instance_type.split(/\./).collect(&:to_sym)
    iclass ||= :t3a
    itype ||= :small
    itype_index = KNOWN_INSTANCE_TYPES.find_index(itype).to_i - 2 # :small is 0th index, :nano is -2
    itype_factor = INSTANCE_TYPE_SCALE_FACTOR**itype_index
    iclass_factor = INSTANCE_CLASS_SCALE_FACTOR[iclass] || INSTANCE_CLASS_SCALE_FACTOR[:t3a]
    self.max_threads_per_agent(iclass_factor * itype_factor * MIN_THREADS_ONE_AGENT)
  end

  def self.max_threads_per_agent(computed)
    pivot = if computed <= 10
              5
            else
              computed <= 50 ? 10 : 50
            end
    (computed.to_f / pivot).round * pivot
  end
end
