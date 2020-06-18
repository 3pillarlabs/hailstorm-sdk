require 'hailstorm/support'
require 'aws'
require 'delegate'
require 'hailstorm/behavior/loggable'

# AWS SDK adapter.
# Route all calls to AWS SDK through this adapter.
class Hailstorm::Support::AwsAdapter
  include Hailstorm::Behavior::Loggable

  # Eager load AWS components
  def self.eager_autoload!
    AWS.eager_autoload!
  end

  # EC2 adapter
  class EC2
    include Hailstorm::Behavior::Loggable

    attr_accessor :vpc_subnet_id

    attr_reader :ec2

    # @param [Hash] aws_config
    def initialize(aws_config, ec2: nil, vpc: nil)
      self.vpc_subnet_id = aws_config[:vpc_subnet_id]
      @ec2 = ec2 || ec2_resource(aws_config.except(:region, :vpc_subnet_id)).regions[aws_config[:region]]
      @vpc = vpc
    end

    # @return [Hailstorm::Support::AwsAdapter::EC2::VPC]
    def vpc
      @vpc ||= (self.vpc_subnet_id ? vpc_from(subnet_id: vpc_subnet_id) : nil)
    end

    # @return [String]
    def first_available_zone
      zone = ec2.availability_zones.find { |z| z.state == :available }
      zone ? zone.name : nil
    end

    # @return [Hailstorm::Support::AwsAdapter::EC2::InternetGateway]
    def create_internet_gateway
      InternetGateway.new(ec2.internet_gateways.create)
    end

    # @return [Enumerator<Hailstorm::Support::AwsAdapter::EC2::Snapshot>]
    def find_self_owned_snapshots
      ec2.snapshots.with_owner(:self).lazy.map { |e| Snapshot.new(e) }
    end

    # Instance methods for working with EC2 key pairs.
    module KeyPairMethods
      # Finds a key pair by name, returns nil if not found.
      # @param [String] name
      # @return [Hailstorm::Support::AwsAdapter::EC2::KeyPair]
      def find_key_pair(name:)
        key_pair = ec2.key_pairs[name]
        key_pair.exists? ? KeyPair.new(key_pair) : nil
      end

      # @param [String] name
      # @return [Hailstorm::Support::AwsAdapter::EC2::KeyPair]
      def create_key_pair(name:)
        KeyPair.new(ec2.key_pairs.create(name))
      end

      # @return [Enumerator<Hailstorm::Support::AwsAdapter::EC2::KeyPair>]
      def all_key_pairs
        ec2.key_pairs.lazy.map { |e| KeyPair.new(e) }
      end
    end

    # Instance methods for AWS security group
    module SecurityGroupMethods

      # @param [String] name
      # @return [Hailstorm::Support::AwsAdapter::EC2::SecurityGroup]
      def find_security_group(name:)
        security_group = (vpc || ec2).security_groups.filter('group-name', name).first
        security_group ? SecurityGroup.new(security_group) : nil
      end

      # @param [String] name
      # @param [Hash] kwargs
      # @return [Hailstorm::Support::AwsAdapter::EC2::SecurityGroup]
      def create_security_group(name:, **kwargs)
        SecurityGroup.new((vpc || ec2).security_groups.create(name, **kwargs))
      end

      # @return [Enumerator<Hailstorm::Support::AwsAdapter::EC2::SecurityGroup>]
      def all_security_groups
        ec2.security_groups.lazy.map { |e| SecurityGroup.new(e) }
      end
    end

    # Instance methods for EC2 Instance
    module Ec2InstanceMethods

      # @param [String] instance_id
      # @return [Hailstorm::Support::AwsAdapter::EC2::Instance]
      def find_instance(instance_id:)
        instance = ec2.instances[instance_id]
        instance ? Instance.new(instance) : nil
      end

      # @param [Hash] attrs EC2 instance attributes
      # @return [Hailstorm::Support::AwsAdapter::EC2::Instance]
      def create_instance(attrs)
        Instance.new(ec2.instances.create(attrs))
      end

      # @return [Enumerator<Hailstorm::Support::AwsAdapter::EC2::Instance>]
      def all_instances
        ec2.instances.lazy.map { |e| Instance.new(e) }
      end

      # @param [Hailstorm::Support::AwsAdapter::EC2::Instance] instance
      # @return [Boolean]
      def instance_ready?(instance)
        instance.exists?.tap { |x| logger.debug { "instance.exists?: #{x}" } } &&
          instance.status.eql?(:running).tap { |x| logger.debug { "instance.status: #{x}" } } &&
          systems_ok(instance).tap { |x| logger.debug { "systems_ok: #{x}" } }
      end

      private

      def systems_ok(instance)
        reachability_pass = ->(f) { f[:name] == 'reachability' && f[:status] == 'passed' }
        describe_instance_status(instance).reduce(true) do |state, e|
          system_reachable = e[:system_status][:details].select { |f| reachability_pass.call(f) }.empty?
          instance_reachable = e[:instance_status][:details].select { |f| reachability_pass.call(f) }.empty?
          state && !system_reachable && !instance_reachable
        end
      end

      def describe_instance_status(ec2_instance)
        ec2.client.describe_instance_status(instance_ids: [ec2_instance.id])[:instance_status_set]
      end
    end

    # Instance methods for AMI
    module AmiMethods

      # @param [Regexp] regexp regular expression to match the AMI name
      # @return [Hailstorm::Support::AwsAdapter::EC2::Image]
      def find_self_owned_ami(regexp:)
        ami = ec2.images.with_owner(:self).find { |e| e.state == :available && regexp.match(e.name) }
        ami ? Image.new(ami) : nil
      end

      # @param [String] name
      # @param [String] instance_id
      # @param [String] description
      # @return [Hailstorm::Support::AwsAdapter::EC2::Image]
      def register_ami(name:, instance_id:, description:)
        Image.new(ec2.images.create(name: name, instance_id: instance_id, description: description))
      end
    end

    # Instance methods for Subnet
    module SubnetMethods

      # @param [String] name_tag
      def find_subnet(name_tag:)
        subnet = ec2.subnets.with_tag('Name', name_tag).first
        subnet ? Subnet.new(subnet) : nil
      end

      # @param [Hailstorm::Support::AwsAdapter::EC2::VPC] vpc
      # @param [String] cidr
      # @return [Hailstorm::Support::AwsAdapter::EC2::Subnet]
      def create_subnet(vpc:, cidr:)
        Subnet.new(vpc.subnets.create(cidr))
      end
    end

    # Instance methods for VPC
    module VpcMethods

      # @param [String] vpc_id
      # @param [Hash] kwargs
      def modify_vpc_attribute(vpc_id, **kwargs)
        ec2.client.modify_vpc_attribute(kwargs.merge(vpc_id: vpc_id))
      end

      # @param [String] cidr
      # @return [Hailstorm::Support::AwsAdapter::EC2::VPC]
      def create_vpc(cidr:)
        VPC.new(ec2.vpcs.create(cidr))
      end

      # @param [Hailstorm::Support::AwsAdapter::EC2::VPC] vpc
      # @return [Hailstorm::Support::AwsAdapter::EC2::RouteTable]
      def create_route_table(vpc:)
        RouteTable.new(ec2.route_tables.create(vpc: vpc))
      end
    end

    include KeyPairMethods
    include SecurityGroupMethods
    include Ec2InstanceMethods
    include AmiMethods
    include SubnetMethods
    include VpcMethods

    # Wrapper for AWS KeyPair type
    class KeyPair < SimpleDelegator; end

    # Wrapper for AWS Instance
    class Instance < SimpleDelegator; end

    # Wrapper for AWS SecurityGroup
    class SecurityGroup < SimpleDelegator; end

    # Wrapper for AWS EC2 Image
    class Image < SimpleDelegator; end

    # Wrapper for AWS Subnet
    class Subnet < SimpleDelegator; end

    # Wrapper for AWS EC2 VPC
    class VPC < SimpleDelegator; end

    # Wrapper for AWS EC2 InternetGateway
    class InternetGateway < SimpleDelegator; end

    # Wrapper for Route Table
    class RouteTable < SimpleDelegator; end

    # Wrapper for Snapshot
    class Snapshot < SimpleDelegator; end

    private

    # @param [Hash] aws_config
    # @return [AWS::EC2]
    def ec2_resource(aws_config)
      AWS::EC2.new(aws_config)
    end

    # @param [String] subnet_id
    # @return [Hailstorm::Support::AwsAdapter::EC2::VPC]
    def vpc_from(subnet_id:)
      VPC.new(ec2.subnets[subnet_id].vpc)
    end
  end
end
