# frozen_string_literal: true

require 'hailstorm/behavior'
require 'hailstorm/behavior/aws_adapter_domain'

# AWS adapter namespace for resource specific interfaces
module Hailstorm::Behavior::AwsAdaptable
  include Hailstorm::Behavior::AwsAdapterDomain

  # Tag interface
  module Taggable
    # :nocov:
    # Name tag an AWS resource
    # @param [String] resource_id
    # @param [String] name
    def tag_name(resource_id:, name:)
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end
    # :nocov:
  end

  # AWS E2 interface
  module Ec2Client
    include Taggable

    # :nocov:
    # @return [String]
    def first_available_zone
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end

    # @return [Enumerator<Snapshot>]
    def find_self_owned_snapshots
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end

    # @param [String] snapshot_id
    def delete_snapshot(snapshot_id:)
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end
    # :nocov:
  end

  # AWS EC2 KeyPair interface
  module KeyPairClient
    include Taggable

    # :nocov:
    # Looks for a key_pair with name. If found, it returns the key_pair_id, nil otherwise.
    # @param [String] name
    # @return [String] key_pair_id
    def find(name:)
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end

    # @param [String] key_pair_id
    def delete(key_pair_id:)
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end

    # @param [String] name
    # @return [KeyPair]
    def create(name:)
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end

    # @return [Enumerator<KeyPairInfo>]
    def list
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end
    # :nocov:
  end

  # AWS Security Group interface
  module SecurityGroupClient
    include Taggable

    # :nocov:
    # @param [String] name
    # @param [String] vpc_id
    # @param [Array<Symbol, Hash>] filters accepts :created (tag:created) or Hash#keys name, values
    # @return [SecurityGroup]
    def find(name:, vpc_id: nil, filters: [])
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end

    # @param [String] name
    # @param [String] description
    # @param [String] vpc_id
    # @return [SecurityGroup]
    def create(name:, description:, vpc_id: nil)
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end

    # @param [String] group_id
    # @param [Symbol] protocol
    # @param [Integer|Range] port_or_range
    # @param [String] cidr
    def authorize_ingress(group_id:, protocol:, port_or_range:, cidr: nil)
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end

    # @param [String] group_id
    def allow_ping(group_id:)
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end

    # @return [Enumerator<SecurityGroup>]
    def list
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end

    # @param [String] group_id
    def delete(group_id:)
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end
    # :nocov:
  end

  # AWS Instance interface
  module InstanceClient
    include Taggable

    # :nocov:
    # Find instance with instance_id, return nil otherwise.
    # Additional predicate methods on return value of the form "#{status}?", example stopped?
    # @param [String] instance_id
    # @return [Instance]
    def find(instance_id:)
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end

    # Starts the instance and returns immediately.
    # Additional predicate methods on return value of the form "#{status}?", example pending?
    # @param [String] instance_id
    # @return [InstanceStateChange]
    def start(instance_id:)
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end

    # Stops the instance and returns immediately.
    # Additional predicate methods on return value of the form "#{status}?", example stopping?
    # @param [String] instance_id
    # @return [InstanceStateChange]
    def stop(instance_id:)
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end

    # Terminates the instance and returns immediately.
    # Additional predicate methods on return value of the form "#{status}?", example shutting_down?
    # @param [String] instance_id
    # @return [InstanceStateChange]
    def terminate(instance_id:)
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end

    # Queries for the instance state, and returns false if the instance does not exist
    # or is not running.
    # @param [String] instance_id
    # @return [Boolean]
    def running?(instance_id:)
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end

    # Queries for the instance state, and returns true if the instance does not exist
    # or is stopped.
    # @param [String] instance_id
    # @return [Boolean]
    def stopped?(instance_id:)
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end

    # Queries for the instance state, and returns true if the instance does not exist
    # or is terminated.
    # @param [String] instance_id
    # @return [Boolean]
    def terminated?(instance_id:)
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end

    # Queries the instance state, and returns true if both instance and system checks are successful
    # @param [String] instance_id
    def ready?(instance_id:)
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end

    # @param [Hash] _instance_attrs
    # @param [Integer] min_count
    # @param [Integer] max_count
    # @return [Instance]
    def create(_instance_attrs, min_count: 1, max_count: 1)
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end

    # @param [Array<String>] instance_ids
    # @return [Enumerator<Instance>]
    def list(instance_ids: nil)
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end
    # :nocov:
  end

  # AWS AMI interface
  module AmiClient
    include Taggable

    # :nocov:
    # @param [Regexp] ami_name_regexp
    # @return [Ami] First AMI with name tag matching the regular expression
    def find_self_owned(ami_name_regexp:)
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end

    # @param [String] name
    # @param [String] instance_id
    # @param [String] description
    # @return [String] image_id
    def register_ami(name:, instance_id:, description:)
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end

    # Queries the current state of the AMI.
    # @param [String] ami_id
    # @return [Boolean] true if ami with ami_id exists and is available
    def available?(ami_id:)
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end

    # @param [String] ami_id
    def deregister(ami_id:)
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end

    # Find AMI by ami_id
    # @param [String] ami_id
    # @param [Array<Symbol, Hash>] filters accepts :created (tag:created) or Hash#keys name, values
    # @return [Ami]
    def find(ami_id:, filters: [])
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end

    # @param [Regexp] ami_name_regexp
    # @return [Array<Ami>] AMIs with name tag matching the regular expression
    def select_self_owned(ami_name_regexp:)
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end
    # :nocov:
  end

  # AWS Subnet interface
  module SubnetClient
    include Taggable

    # :nocov:
    # @param [String] subnet_id
    # @param [String] name_tag
    # @param [Array<Symbol, Hash>] filters accepts :created (tag:created) or Hash#keys name, values
    # @return [String] subnet_id
    def find(subnet_id: nil, name_tag: nil, filters: [])
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end

    # @param [String] vpc_id
    # @param [String] cidr
    # @return [String] subnet_id
    def create(vpc_id:, cidr:)
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end

    # Queries the Subnet status and returns true if available
    # @param [String] subnet_id
    # @return [Boolean]
    def available?(subnet_id:)
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end

    # @param [String] subnet_id
    # @param [Hash] _kwargs
    def modify_attribute(subnet_id:, **_kwargs)
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end

    # @param [String] subnet_id
    def delete(subnet_id:)
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end

    # @param [String] subnet_id
    # @return [String, NilClass]
    def find_vpc(subnet_id:)
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end
    # :nocov:
  end

  # AWS VPC interface
  module VpcClient
    include Taggable

    # :nocov:
    # @param [String] vpc_id
    # @param [Hash] _kwargs
    def modify_attribute(vpc_id:, **_kwargs)
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end

    # @param [String] cidr
    # @return [String] vpc_id
    def create(cidr:)
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end

    # Queries the status of the VPC and returns true if VPC exists and is available.
    # @param [String] vpc_id
    # @return [Boolean]
    def available?(vpc_id:)
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end

    # @param [String] vpc_id
    # @param [Array<Symbol, Hash>] filters accepts :created (tag:created) or Hash#keys name, values
    # @return [Hailstorm::Behavior::AwsAdapterDomain::Vpc, Nil] Vpc
    def find(vpc_id:, filters: [])
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end

    # @param [String] vpc_id
    def delete(vpc_id:)
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end
    # :nocov:
  end

  # Internet gateway interface
  module InternetGatewayClient
    include Taggable

    # :nocov:
    # @return [String] internet_gateway_id
    def create
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end

    # @param [String] igw_id
    # @param [String] vpc_id
    def attach(igw_id:, vpc_id:)
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end

    # @param [String] vpc_id
    # @param [Array<Symbol>] filters accepted :created
    def select(vpc_id:, filters: [])
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end

    # @param [String] igw_id
    def delete(igw_id:)
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end

    # @param [String] igw_id
    # @param [String] vpc_id
    def detach_from_vpc(igw_id:, vpc_id:)
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end
    # :nocov:
  end

  # Route Table interface
  module RouteTableClient
    include Taggable

    # :nocov:
    # @param [String] route_table_id
    # @param [String] subnet_id
    # @return [String] association_id
    def associate_with_subnet(route_table_id:, subnet_id:)
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end

    # @param [String] vpc_id
    # @return [String] route_table_id
    def main_route_table(vpc_id:)
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end

    # @param [String] vpc_id
    # @return [String] route_table_id
    def create(vpc_id:)
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end

    # @param [String] route_table_id
    # @param [String] cidr
    # @param [String] internet_gateway_id
    def create_route(route_table_id:, cidr:, internet_gateway_id:)
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end

    # @param [String] route_table_id
    # @return [Array<Route>]
    def routes(route_table_id:)
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end

    # @param [String] vpc_id
    # @param [Array<Symbol>] filters known filters :created
    # @return [Enumerable<RouteTable>]
    def route_tables(vpc_id:, filters: [])
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end

    # @param [String] route_table_id
    def delete(route_table_id:)
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end
    # :nocov:
  end
end
