require 'hailstorm/support'
require 'aws-sdk'
require 'delegate'
require 'hailstorm/behavior/loggable'

# AWS SDK adapter.
# Route all calls to AWS SDK through this adapter.
class Hailstorm::Support::AwsAdapter
  include Hailstorm::Behavior::Loggable

  # Eager load AWS components
  def self.eager_autoload!
    Aws.eager_autoload!
  end

  # EC2 adapter
  class EC2
    include Hailstorm::Behavior::Loggable

    attr_accessor :vpc_subnet_id

    # @return [Aws::EC2::Resource]
    attr_reader :ec2

    # @param [Hash] aws_config
    def initialize(aws_config, ec2: nil, vpc: nil)
      self.vpc_subnet_id = aws_config[:vpc_subnet_id]
      @ec2 = ec2 || ec2_resource(aws_config.except(:vpc_subnet_id))
      @vpc = vpc
    end

    # @return [Hailstorm::Support::AwsAdapter::EC2::VPC]
    def vpc
      @vpc ||= self.vpc_subnet_id ? vpc_from(subnet_id: vpc_subnet_id) : nil
    end

    # @return [String]
    def first_available_zone
      zone = ec2.client
                .describe_availability_zones.to_h[:availability_zones]
                .find { |z| z[:state].to_sym == :available }
      zone ? zone[:zone_name] : nil
    end

    # @return [Hailstorm::Support::AwsAdapter::EC2::InternetGateway]
    def create_internet_gateway
      InternetGateway.new(ec2.create_internet_gateway)
    end

    # @return [Enumerator<Hailstorm::Support::AwsAdapter::EC2::Snapshot>]
    def find_self_owned_snapshots
      ec2.snapshots(owner_ids: %w[self]).lazy.map { |e| Snapshot.new(e) }
    end

    # Instance methods for working with EC2 key pairs.
    module KeyPairMethods
      # Finds a key pair by name, returns nil if not found.
      # @param [String] name
      # @return [Hailstorm::Support::AwsAdapter::EC2::KeyPair]
      def find_key_pair(name:)
        key_pair = ec2.key_pair(name)
        key_pair ? KeyPair.new(key_pair) : nil
      end

      # @param [String] name
      # @return [Hailstorm::Support::AwsAdapter::EC2::KeyPair]
      def create_key_pair(name:)
        KeyPair.new(ec2.create_key_pair(key_name: name))
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
        security_group = (vpc || ec2).security_groups(filters: [{name: 'group-name', values: [name]}]).first
        security_group ? SecurityGroup.new(security_group) : nil
      end

      # @param [String] name
      # @param [Hash] kwargs
      # @return [Hailstorm::Support::AwsAdapter::EC2::SecurityGroup]
      def create_security_group(name:, **kwargs)
        attrs = kwargs.except(:vpc)
        attrs[:vpc_id] = kwargs[:vpc].vpc_id if kwargs.key?(:vpc)
        attrs[:group_name] = name
        SecurityGroup.new(ec2.create_security_group(attrs))
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
        instance = ec2.instances(instance_ids: [instance_id]).first
        instance ? Instance.new(instance) : nil
      end

      # @param [Hash] attrs EC2 instance attributes
      # @return [Hailstorm::Support::AwsAdapter::EC2::Instance]
      def create_instance(attrs, min_count: 1, max_count: 1)
        req_attrs = attrs.except(:availability_zone, :associate_public_ip_address)
        req_attrs.merge!(min_count: min_count, max_count: max_count)
        req_attrs.merge!(placement: {availability_zone: attrs[:availability_zone]}) if attrs.key?(:availability_zone)
        instance = ec2.create_instances(req_attrs).first
        Instance.new(ec2.instance(instance.id))
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

      # @param [Hailstorm::Support::AwsAdapter::EC2::Instance] instance
      def refresh_instance!(instance)
        ec2_instance = ec2.instance(instance.instance_id)
        instance.__setobj__(ec2_instance)
        instance
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
        ec2.client.describe_instance_status(instance_ids: [ec2_instance.id]).to_h[:instance_statuses]
      end
    end

    # Instance methods for AMI
    module AmiMethods

      # @param [Regexp] regexp regular expression to match the AMI name
      # @return [Hailstorm::Support::AwsAdapter::EC2::Image]
      def find_self_owned_ami(regexp:)
        ami = ec2.images(owners: [:self.to_s]).find { |e| e.state.to_sym == :available && regexp.match(e.name) }
        ami ? Image.new(ami) : nil
      end

      # @param [String] name
      # @param [String] instance_id
      # @param [String] description
      # @return [Hailstorm::Support::AwsAdapter::EC2::Image]
      def register_ami(name:, instance_id:, description:)
        resp = ec2.client.create_image(name: name, instance_id: instance_id, description: description)
        Image.new(ec2.image(resp.to_h[:image_id]))
      end

      # Updates the delegation object
      # @param [Hailstorm::Support::AwsAdapter::EC2::Image] ami
      # @return [Hailstorm::Support::AwsAdapter::EC2::Image]
      def refresh_ami!(ami)
        ec2_image = ec2.image(ami.image_id)
        ami.__setobj__(ec2_image)
        ami
      end
    end

    # Instance methods for Subnet
    module SubnetMethods

      # @param [String] name_tag
      def find_subnet(name_tag:)
        subnet = ec2.subnets(filters: [{name: 'tag:Name', values: [name_tag]}]).first
        subnet ? Subnet.new(subnet) : nil
      end

      # @param [Hailstorm::Support::AwsAdapter::EC2::VPC] vpc
      # @param [String] cidr
      # @return [Hailstorm::Support::AwsAdapter::EC2::Subnet]
      def create_subnet(vpc:, cidr:)
        Subnet.new(vpc.create_subnet(cidr_block: cidr))
      end

      # @param [Hailstorm::Support::AwsAdapter::EC2::Subnet] subnet
      # @param [Hash] kwargs
      def modify_subnet_attribute(subnet, **kwargs)
        attrs = kwargs.reduce({}) { |s, e| s.merge(e.first => {value: e.last}) }
        attrs.merge!(subnet_id: subnet.subnet_id)
        ec2.client.modify_subnet_attribute(attrs)
      end

      # @param [Hailstorm::Support::AwsAdapter::EC2::Subnet] subnet
      def refresh_subnet!(subnet)
        ec2_subnet = ec2.subnet(subnet.subnet_id)
        subnet.__setobj__(ec2_subnet)
        subnet
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
        VPC.new(ec2.create_vpc(cidr_block: cidr))
      end

      # @param [Hailstorm::Support::AwsAdapter::EC2::VPC] vpc
      # @return [Hailstorm::Support::AwsAdapter::EC2::RouteTable]
      def create_route_table(vpc:)
        RouteTable.new(ec2.create_route_table(vpc_id: vpc.id))
      end

      # @param [Hailstorm::Support::AwsAdapter::EC2::VPC] vpc
      def refresh_vpc!(vpc)
        ec2_vpc = ec2.vpc(vpc.vpc_id)
        vpc.__setobj__(ec2_vpc)
        vpc
      end

      # @param [Hailstorm::Support::AwsAdapter::EC2::VPC] vpc
      # @return [Hailstorm::Support::AwsAdapter::EC2::RouteTable]
      def main_route_table(vpc:)
        rtb = vpc.route_tables.first
        rtb ? RouteTable.new(rtb) : nil
      end
    end

    include KeyPairMethods
    include SecurityGroupMethods
    include Ec2InstanceMethods
    include AmiMethods
    include SubnetMethods
    include VpcMethods

    # For resources that are taggable
    module Taggable

      # @param [String] key
      # @param [String] value
      def tag(key, value:)
        create_tags(tags: [{key: key, value: value}])
      end
    end

    # Wrapper for AWS KeyPair type
    class KeyPair < SimpleDelegator
      def private_key
        key_material
      end
    end

    # Wrapper for AWS Instance
    class Instance < SimpleDelegator
      include Taggable

      def status
        state.name.to_sym
      end

      def stopped?
        status == :stopped
      end

      def terminated?
        status == :terminated
      end

      def running?
        status == :running
      end
    end

    # Wrapper for AWS SecurityGroup
    class SecurityGroup < SimpleDelegator
      def name
        group_name
      end

      def authorize_ingress(proto, port_or_range, cidr: nil)
        ip_perm = { ip_protocol: proto }
        ip_perm[:from_port] = port_or_range.is_a?(Range) ? port_or_range.first : port_or_range
        ip_perm[:to_port] = port_or_range.is_a?(Range) ? port_or_range.last : port_or_range
        ip_perm[:ip_ranges] = [{ cidr_ip: nil }]
        if cidr
          ip_perm[:ip_ranges].first[:cidr_ip] = cidr == :anywhere ? '0.0.0.0/0' : cidr
        else
          ip_perm[:user_id_group_pairs] = [{group_id: group_id}]
        end

        __getobj__.authorize_ingress(ip_permissions: [ip_perm])
      end

      def allow_ping
        authorize_ingress(:icmp, -1, cidr: :anywhere)
      end
    end

    # Wrapper for AWS EC2 Image
    class Image < SimpleDelegator
      def state
        __getobj__.state.to_sym
      end

      def available?
        state == :available
      end
    end

    # Wrapper for AWS Subnet
    class Subnet < SimpleDelegator
      include Taggable

      def available?
        state.to_sym == :available
      end
    end

    # Wrapper for AWS EC2 VPC
    class VPC < SimpleDelegator
      include Taggable

      def available?
        state.to_sym == :available
      end
    end

    # Wrapper for AWS EC2 InternetGateway
    class InternetGateway < SimpleDelegator
      include Taggable

      # @param [Hailstorm::Support::AwsAdapter::EC2::VPC] vpc
      def attach(vpc)
        attach_to_vpc(vpc_id: vpc.vpc_id)
      end
    end

    # Wrapper for Route Table
    class RouteTable < SimpleDelegator

      # @param [String] destination
      # @param [Hailstorm::Support::AwsAdapter::EC2::InternetGateway] internet_gateway
      def create_route(destination, internet_gateway:)
        __getobj__.create_route(
          destination_cidr_block: destination,
          gateway_id: internet_gateway.internet_gateway_id
        )
      end
    end

    # Wrapper for Snapshot
    class Snapshot < SimpleDelegator

      # @return [Symbol] one of :pending, :completed, or :error
      def status
        state.to_sym
      end
    end

    private

    # @param [Hash] aws_config
    # @return [Aws::EC2::Resource]
    def ec2_resource(aws_config)
      ec2_client = Aws::EC2::Client.new(
        region: aws_config[:region],
        credentials: Aws::Credentials.new(aws_config[:access_key_id], aws_config[:secret_access_key])
      )

      Aws::EC2::Resource.new(client: ec2_client)
    end

    # @param [String] subnet_id
    # @return [Hailstorm::Support::AwsAdapter::EC2::VPC]
    def vpc_from(subnet_id:)
      VPC.new(ec2.subnet(subnet_id).vpc)
    end
  end
end
