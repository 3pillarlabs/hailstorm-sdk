require 'hailstorm/model/helper'
require 'hailstorm/model/helper/security_group_finder'
require 'hailstorm/behavior/loggable'

# Helper method for creating Hailstorm security group
class Hailstorm::Model::Helper::SecurityGroupCreator < Hailstorm::Model::Helper::SecurityGroupFinder
  include Hailstorm::Behavior::Loggable

  attr_reader :security_group_desc, :ssh_port, :security_group_client, :ec2_client, :vpc_subnet_id
  attr_reader :security_group, :region

  # @param [Hailstorm::Behavior::AwsAdaptable::SecurityGroupClient] security_group_client
  # @param [Hailstorm::Behavior::AwsAdaptable::Ec2Client] ec2_client
  # @param [String] vpc_subnet_id
  # @param [Integer] ssh_port
  # @param [String] security_group tag name
  # @param [String] region
  # @param [String] security_group_desc
  def initialize(security_group_client:,
                 ec2_client:,
                 vpc_subnet_id: nil,
                 ssh_port:,
                 security_group:,
                 region:,
                 security_group_desc:)

    @security_group_client = security_group_client
    @ec2_client = ec2_client
    @vpc_subnet_id = vpc_subnet_id
    @ssh_port = ssh_port
    @security_group = security_group
    @region = region
    @security_group_desc = security_group_desc
  end

  def create_security_group
    logger.debug { "#{self.class}##{__method__}" }
    vpc_id = find_vpc
    security_group = find_security_group(vpc_id: vpc_id)
    unless security_group
      logger.info("Creating #{self.security_group} security group on #{self.region}...")
      security_group = security_group_client.create(name: self.security_group,
                                                    description: self.security_group_desc,
                                                    vpc_id: vpc_id)

      # allow SSH from anywhere
      port_or_range = self.ssh_port
      security_group_client.authorize_ingress(group_id: security_group.group_id,
                                              protocol: :tcp,
                                              port_or_range: port_or_range,
                                              cidr: :anywhere)

      # allow incoming TCP & UDP to any port within the group
      %i[tcp udp].each do |proto|
        security_group_client.authorize_ingress(group_id: security_group.group_id,
                                                protocol: proto,
                                                port_or_range: 0..65_535)
      end

      security_group_client.allow_ping(group_id: security_group.group_id) # allow ICMP from anywhere
    end

    security_group
  end
end
