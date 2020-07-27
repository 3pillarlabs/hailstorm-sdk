require 'hailstorm/support'
require 'aws-sdk-ec2'
require 'delegate'
require 'hailstorm/behavior/loggable'
require 'hailstorm/behavior/aws_adaptable'
require 'ostruct'

# AWS SDK adapter.
# Route all calls to AWS SDK through this adapter.
class Hailstorm::Support::AwsAdapter
  include Hailstorm::Behavior::Loggable

  # Abstract class for all client adapters.
  class AbstractClient
    include Hailstorm::Behavior::Loggable
    include Hailstorm::Behavior::AwsAdaptable::Taggable

    # @return [Aws::EC2::Client]
    attr_reader :ec2

    # @param [Aws::EC2::Client] ec2_client
    def initialize(ec2_client:)
      @ec2 = ec2_client
    end

    def tag_name(resource_id:, name:)
      ec2.create_tags(resources: [resource_id], tags: [{key: 'Name', value: name }])
    end
  end

  # Client adapter for EC2 methods invoked
  class Ec2Client < AbstractClient
    include Hailstorm::Behavior::AwsAdaptable::Ec2Client

    def first_available_zone
      zone = ec2.describe_availability_zones
                .availability_zones
                .find { |z| z.state.to_sym == :available }

      zone ? zone.zone_name : nil
    end

    def find_vpc(subnet_id:)
      resp = ec2.describe_subnets(subnet_ids: [subnet_id])
      return nil if resp.subnets.empty?

      resp.subnets[0].vpc_id
    end

    def find_self_owned_snapshots
      resp = ec2.describe_snapshots(owner_ids: ['self'])
      resp.snapshots.lazy.map do |snapshot|
        Hailstorm::Behavior::AwsAdaptable::Snapshot.new(snapshot_id: snapshot.snapshot_id, state: snapshot.state)
      end
    end

    def delete_snapshot(snapshot_id:)
      ec2.delete_snapshot(snapshot_id: snapshot_id)
    end
  end

  # AWS KeyPair adapter
  class KeyPairClient < AbstractClient
    include Hailstorm::Behavior::AwsAdaptable::KeyPairClient

    def find(name:)
      resp = ec2.describe_key_pairs(key_names: [name])
      key_pair_info = resp.to_h[:key_pairs].first
      key_pair_info ? key_pair_info[:key_pair_id] : nil
    rescue Aws::EC2::Errors::ServiceError
      return nil
    end

    def delete(key_pair_id:)
      ec2.delete_key_pair(key_pair_id: key_pair_id)
    end

    def create(name:)
      resp = ec2.create_key_pair(key_name: name)
      attribute_keys = %i[key_fingerprint key_material key_name key_pair_id]
      Hailstorm::Behavior::AwsAdaptable::KeyPair.new(resp.to_h.slice(*attribute_keys))
    end

    def list
      ec2.describe_key_pairs.key_pairs.lazy.map do |key_pair|
        Hailstorm::Behavior::AwsAdaptable::KeyPairInfo.new(key_pair.to_h)
      end
    end
  end

  class InstanceClient < AbstractClient
    include Hailstorm::Behavior::AwsAdaptable::InstanceClient

    def find(instance_id:)
      resp = ec2.describe_instances(instance_ids: [instance_id])
      return if resp.reservations.blank? || resp.reservations[0].instances.blank?

      decorate(instance: resp.reservations[0].instances[0])
    end

    def decorate(instance:)
      Hailstorm::Behavior::AwsAdaptable::Instance.new(
        instance_id: instance.instance_id,
        state: Hailstorm::Behavior::AwsAdaptable::InstanceState.new(
          name: instance.state.name,
          code: instance.state.code
        ),
        public_ip_address: instance.public_ip_address,
        private_ip_address: instance.private_ip_address
      )
    end
    private :decorate

    def running?(instance_id:)
      instance = find(instance_id: instance_id)
      instance ? instance.running? : false
    end

    def start(instance_id:)
      resp = ec2.start_instances(instance_ids: [instance_id])
      return if resp.starting_instances.empty?

      result = resp.starting_instances[0]
      to_transitional_attributes(result)
    end

    # @param [Aws::EC2::Types::InstanceStateChange] result
    # @return [Hailstorm::Behavior::AwsAdaptable::InstanceStateChange]
    def to_transitional_attributes(result)
      Hailstorm::Behavior::AwsAdaptable::InstanceStateChange.new(
        instance_id: result.instance_id,
        current_state: result.current_state,
        previous_state: result.previous_state
      )
    end
    private :to_transitional_attributes

    def stop(instance_id:)
      resp = ec2.stop_instances(instance_ids: [instance_id])
      return if resp.stopping_instances.empty?

      result = resp.stopping_instances[0]
      to_transitional_attributes(result)
    end

    def stopped?(instance_id:)
      instance = find(instance_id: instance_id)
      instance ? instance.stopped? : true
    end

    def terminate(instance_id:)
      resp = ec2.terminate_instances(instance_ids: [instance_id])
      return if resp.terminating_instances.empty?

      result = resp.terminating_instances[0]
      to_transitional_attributes(result)
    end

    def terminated?(instance_id:)
      instance = find(instance_id: instance_id)
      instance ? instance.terminated? : true
    end

    def create(instance_attrs, min_count: 1, max_count: 1)
      req_attrs = instance_attrs.except(:availability_zone)
      req_attrs.merge!(min_count: min_count, max_count: max_count)
      req_attrs.merge!(placement: instance_attrs.slice(:availability_zone)) if instance_attrs.key?(:availability_zone)
      instance = ec2.run_instances(req_attrs).instances[0]
      decorate(instance: instance)
    end

    def ready?(instance_id:)
      instance = find(instance_id: instance_id)
      return false unless instance

      logger.debug { instance.to_h }
      instance.running? && systems_ok(instance)
    end

    def systems_ok(instance)
      reachability_pass = ->(f) { f.name == 'reachability' && f.status == 'passed' }
      ec2.describe_instance_status(instance_ids: [instance.id]).instance_statuses.reduce(true) do |state, e|
        system_unreachable = e.system_status.details.select { |f| reachability_pass.call(f) }.empty?
        instance_unreachable = e.instance_status.details.select { |f| reachability_pass.call(f) }.empty?
        state && !system_unreachable && !instance_unreachable
      end
    end
    private :systems_ok

    def list
      ec2.describe_instances.reservations.flat_map(&:instances).lazy.map { |instance| decorate(instance: instance) }
    end
  end

  # AWS security group client
  class SecurityGroupClient < AbstractClient
    include Hailstorm::Behavior::AwsAdaptable::SecurityGroupClient

    def find(name:, vpc_id: nil)
      filters = [{ name: 'group-name', values: [name] }]
      filters.push({ name: 'vpc-id', values: [vpc_id] }) if vpc_id
      resp = ec2.describe_security_groups(filters: filters)
      return if resp.security_groups.empty?

      security_group = resp.security_groups[0]
      sg_attrs = { group_name: security_group.group_name, group_id: security_group.group_id }
      sg_attrs[:vpc_id] = security_group.vpc_id if security_group.respond_to?(:vpc_id)
      Hailstorm::Behavior::AwsAdaptable::SecurityGroup.new(sg_attrs)
    end

    def create(name:, description:, vpc_id: nil)
      resp = ec2.create_security_group(group_name: name, description: description, vpc_id: vpc_id)
      Hailstorm::Behavior::AwsAdaptable::SecurityGroup.new(group_id: resp.group_id)
    end

    def authorize_ingress(group_id:, protocol:, port_or_range:, cidr: nil)
      ip_perm = { ip_protocol: protocol.to_s }
      ip_perm[:from_port] = port_or_range.is_a?(Range) ? port_or_range.first : port_or_range
      ip_perm[:to_port] = port_or_range.is_a?(Range) ? port_or_range.last : port_or_range
      ip_perm[:ip_ranges] = [{ cidr_ip: nil }]
      if cidr
        ip_perm[:ip_ranges].first[:cidr_ip] = cidr == :anywhere ? '0.0.0.0/0' : cidr
      else
        ip_perm[:user_id_group_pairs] = [{group_id: group_id}]
      end

      ec2.authorize_security_group_ingress(group_id: group_id, ip_permissions: [ip_perm])
    end

    def allow_ping(group_id:)
      authorize_ingress(group_id: group_id, protocol: :icmp, port_or_range: -1, cidr: :anywhere)
    end

    def delete(group_id:)
      ec2.delete_security_group(group_id: group_id)
    end

    def list
      ec2.describe_security_groups.security_groups.lazy.map do |sg|
        Hailstorm::Behavior::AwsAdaptable::SecurityGroup.new(sg.to_h)
      end
    end
  end

  class AmiClient < AbstractClient
    include Hailstorm::Behavior::AwsAdaptable::AmiClient

    def find_self_owned(ami_name_regexp:)
      ami = ec2.describe_images(owners: [:self.to_s])
               .images
               .find { |e| e.state.to_sym == :available && ami_name_regexp.match(e.name) }
      return unless ami

      decorate(ami)
    end

    # @param [Aws::EC2::Types::Image] ami
    def decorate(ami)
      state_reason = ami.state_reason ?
                     Hailstorm::Behavior::AwsAdaptable::StateReason.new(code: ami.state_reason.code,
                                                                        message: ami.state_reason.message)
                     :
                     nil
      Hailstorm::Behavior::AwsAdaptable::Ami.new(image_id: ami.image_id,
                                                 name: ami.name,
                                                 state: ami.state,
                                                 state_reason: state_reason)
    end
    private :decorate

    # @see Hailstorm::Behavior::AwsAdaptable::AmiClient#available?
    def available?(ami_id:)
      ami = find(ami_id: ami_id)
      ami&.available?
    end

    # @see Hailstorm::Behavior::AwsAdaptable::AmiClient#register_ami
    def register_ami(name:, instance_id:, description:)
      resp = ec2.create_image(name: name, instance_id: instance_id, description: description)
      resp.image_id
    end

    def deregister(ami_id:)
      ec2.deregister_image(image_id: ami_id)
    end

    def find(ami_id:)
      resp = ec2.describe_images(image_ids: [ami_id])
      return nil if resp.images.empty?

      decorate(resp.images[0])
    end
  end

  # Subnet adapter
  class SubnetClient < AbstractClient
    include Hailstorm::Behavior::AwsAdaptable::SubnetClient

    def available?(subnet_id:)
      resp = query(subnet_id: subnet_id)
      !resp.subnets.blank? && resp.subnets[0].state.to_sym == :available
    end

    def create(vpc_id:, cidr:)
      resp = ec2.create_subnet(cidr_block: cidr, vpc_id: vpc_id)
      resp.subnet.subnet_id
    end

    def find(subnet_id: nil, name_tag: nil)
      resp = query(subnet_id: subnet_id, name_tag: name_tag)
      return nil if resp.subnets.empty?

      resp.subnets[0].subnet_id
    end

    def modify_attribute(subnet_id:, **kwargs)
      attrs = kwargs.reduce({}) { |s, e| s.merge(e.first => { value: e.last }) }
      attrs.merge!(subnet_id: subnet_id)
      ec2.modify_subnet_attribute(attrs)
    end

    private

    def query(subnet_id: nil, name_tag: nil)
      params = {}
      params[:subnet_ids] = [subnet_id] if subnet_id
      if name_tag
        params[:filters] = []
        params[:filters].push(name: 'tag:Name', values: [name_tag])
      end

      ec2.describe_subnets(params)
    end
  end

  class VpcClient < AbstractClient
    include Hailstorm::Behavior::AwsAdaptable::VpcClient

    def create(cidr:)
      resp = ec2.create_vpc(cidr_block: cidr)
      resp.vpc.vpc_id
    end

    def modify_attribute(vpc_id:, **kwargs)
      ec2.modify_vpc_attribute(kwargs.transform_values { |v| {value: v} }.merge(vpc_id: vpc_id))
    end

    def available?(vpc_id:)
      resp = ec2.describe_vpcs(vpc_ids: [vpc_id])
      !resp.vpcs.blank? && resp.vpcs[0].state.to_sym == :available
    end
  end

  class InternetGatewayClient < AbstractClient
    include Hailstorm::Behavior::AwsAdaptable::InternetGatewayClient

    def attach(igw_id:, vpc_id:)
      ec2.attach_internet_gateway(internet_gateway_id: igw_id, vpc_id: vpc_id)
    end

    def create
      resp = ec2.create_internet_gateway
      resp.internet_gateway.internet_gateway_id
    end
  end

  class RouteTableClient < AbstractClient
    include Hailstorm::Behavior::AwsAdaptable::RouteTableClient

    def associate_with_subnet(route_table_id:, subnet_id:)
      resp = ec2.associate_route_table(route_table_id: route_table_id, subnet_id: subnet_id)
      resp.association_id
    end

    def create(vpc_id:)
      resp = ec2.create_route_table(vpc_id: vpc_id)
      resp.route_table.route_table_id
    end

    def create_route(route_table_id:, cidr:, internet_gateway_id:)
      ec2.create_route(destination_cidr_block: cidr,
                       gateway_id: internet_gateway_id,
                       route_table_id: route_table_id)
    end

    def main_route_table(vpc_id:)
      resp = ec2.describe_route_tables(filters: [{ name: 'vpc-id', values: [vpc_id] }])
      rtb = resp.route_tables.find do |route_table|
        route_table.associations.any? { |rtb_assoc| rtb_assoc.main }
      end

      rtb ? rtb.route_table_id : nil
    end

    def routes(route_table_id:)
      ec2.describe_route_tables(route_table_ids: [route_table_id])
          .route_tables
          .first
          .routes
          .map { |route| Hailstorm::Behavior::AwsAdaptable::Route.new(state: route.state) }
    end
  end

  # @param [Hash] aws_config(access_key_id secret_access_key region)
  def self.clients(aws_config)
    unless @clients
      credentials = Aws::Credentials.new(aws_config[:access_key_id], aws_config[:secret_access_key])
      ec2_client = Aws::EC2::Client.new(region: aws_config[:region], credentials: credentials)
      factory_attrs = Hailstorm::Behavior::AwsAdaptable::CLIENT_KEYS.reduce({}) do |attrs, ck|
        attrs.merge(
          ck.to_sym => "#{Hailstorm::Support::AwsAdapter.name}::#{ck.to_s.camelize}".constantize
                                                                                    .new(ec2_client: ec2_client)
        )
      end

      @clients = Hailstorm::Behavior::AwsAdaptable::ClientFactory.new(factory_attrs)
    end

    @clients
  end
end
