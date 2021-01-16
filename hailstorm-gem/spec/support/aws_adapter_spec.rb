# frozen_string_literal: true

require 'spec_helper'
require 'hailstorm/support/aws_adapter'
require 'deep_hash_struct'

describe Hailstorm::Support::AwsAdapter do
  include DeepHashStruct

  before(:each) do
    @mock_ec2 = instance_double(Aws::EC2::Client)
  end

  context Hailstorm::Support::AwsAdapter::KeyPairClient do
    before(:each) do
      @client = Hailstorm::Support::AwsAdapter::KeyPairClient.new(ec2_client: @mock_ec2)
    end

    it 'should find a key_pair' do
      key_pair_attrs = deep_struct(key_material: 'A', key_name: 'mock_key_pair', key_pair_id: 'kp-123')
      allow(@mock_ec2).to receive(:describe_key_pairs).and_return(key_pairs: [key_pair_attrs])
      actual_id = @client.find(name: key_pair_attrs.key_name)
      expect(actual_id).to be == key_pair_attrs.key_pair_id
    end

    it 'should return nil if a key pair is not found' do
      class Aws::EC2::Errors::InvalidKeyPairNotFound < Aws::EC2::Errors::ServiceError; end

      not_found = Aws::EC2::Errors::InvalidKeyPairNotFound.new({}, 'mock error')
      allow(@mock_ec2).to receive(:describe_key_pairs).and_raise(not_found)
      expect(@client.find(name: 'misspelled')).to be_nil
    end

    it 'should raise error if finding a key fails due to a reason other than a missing key' do
      other_error = Aws::Errors::ServiceError.new({}, 'mock error')
      allow(@mock_ec2).to receive(:describe_key_pairs).and_raise(other_error)
      proxied_client = Hailstorm::Support::AwsAdapter::ExceptionTranslationProxy.new(@client)
      expect { proxied_client.find(name: 'misspelled') }.to raise_error(Hailstorm::AwsException)
    end

    it 'should delete a key_pair' do
      expect(@mock_ec2).to receive(:delete_key_pair).with(key_pair_id: 'kp-123')
      @client.delete(key_pair_id: 'kp-123')
    end

    it 'should create a key_pair' do
      resp = deep_struct(key_fingerprint: 'AA:00', key_material: 'A', key_name: 'hailstorm', key_pair_id: 'kp-1')
      expect(@mock_ec2).to receive(:create_key_pair).with(key_name: 'hailstorm').and_return(resp)
      key_pair = @client.create(name: 'hailstorm')
      expect(key_pair.private_key).to be == resp.key_material
      expect(key_pair.key_pair_id).to be == resp.key_pair_id
    end

    it 'should list key pairs' do
      resp = deep_struct(key_pairs: [{ key_name: 'hailstorm', key_pair_id: 'kp-1' },
                                     { key_name: 'jmeter', key_pair_id: 'kp-2' }])

      expect(@mock_ec2).to receive(:describe_key_pairs).and_return(resp)
      ite = @client.list
      expect(ite.next.to_h).to include(key_name: 'hailstorm', key_pair_id: 'kp-1')
      expect(ite.next.to_h).to include(key_name: 'jmeter', key_pair_id: 'kp-2')
    end
  end

  context Hailstorm::Support::AwsAdapter::InstanceClient do
    before(:each) do
      @client = Hailstorm::Support::AwsAdapter::InstanceClient.new(ec2_client: @mock_ec2)
    end

    it 'should find an instance' do
      resp_attrs = deep_struct(
        reservations: [
          {
            instances: [
              {
                instance_id: 'i-1234',
                state: { code: 12_345, name: 'running' },
                public_ip_address: '23.45.67.89',
                private_ip_address: '10.0.1.23'
              }
            ]
          }
        ]
      )

      expect(@mock_ec2).to receive(:describe_instances).and_return(resp_attrs)
      instance = @client.find(instance_id: 'i-1234')
      expect(instance).to_not be_nil
      expect(instance.id).to be == 'i-1234'
      expect(instance.status).to be == :running
      expect(instance).to be_running
    end

    it 'should start an instance' do
      resp = deep_struct(
        starting_instances: [
          {
            current_state: { code: 10, name: 'pending' },
            previous_state: { code: 9, name: 'stopped' },
            instance_id: 'i-1234'
          }
        ]
      )

      expect(@mock_ec2).to receive(:start_instances).and_return(resp)
      resp = @client.start(instance_id: 'i-1234')
      expect(resp.id).to be == 'i-1234'
      expect(resp.status).to be == :pending
    end

    it 'should check if an instance is running' do
      instance_state = Hailstorm::Behavior::AwsAdapterDomain::InstanceState.new(name: 'running')
      mock_instance = Hailstorm::Behavior::AwsAdapterDomain::Instance.new(state: instance_state)
      allow(mock_instance).to receive(:running?).and_return(true)
      expect(@client).to receive(:find).and_return(mock_instance)
      expect(@client.running?(instance_id: 'i-1234')).to be true
    end

    it 'should tag an instance by name' do
      expect(@mock_ec2).to receive(:create_tags).with(resources: ['i-123'], tags: [{ key: 'Name', value: 'mine' }])
      @client.tag_name(resource_id: 'i-123', name: 'mine')
    end

    it 'should stop an instance' do
      resp = deep_struct(
        stopping_instances: [
          {
            current_state: { code: 10, name: 'stopping' },
            previous_state: { code: 9, name: 'running' },
            instance_id: 'i-123'
          }
        ]
      )

      expect(@mock_ec2).to receive(:stop_instances).with(instance_ids: ['i-123']).and_return(resp)
      instance = @client.stop(instance_id: 'i-123')
      expect(instance.status).to be == :stopping
    end

    it 'should check if an instance is stopped' do
      instance_state = Hailstorm::Behavior::AwsAdapterDomain::InstanceState.new(name: 'stopped')
      mock_instance = Hailstorm::Behavior::AwsAdapterDomain::Instance.new(state: instance_state)
      allow(mock_instance).to receive(:stopped?).and_return(true)
      expect(@client).to receive(:find).and_return(mock_instance)
      expect(@client.stopped?(instance_id: 'i-1234')).to be true
    end

    it 'should terminate an instance' do
      resp = deep_struct(
        terminating_instances: [
          {
            current_state: { code: 10, name: 'shutting-down' },
            previous_state: { code: 9, name: 'running' },
            instance_id: 'i-123'
          }
        ]
      )

      expect(@mock_ec2).to receive(:terminate_instances).with(instance_ids: ['i-123']).and_return(resp)
      instance = @client.terminate(instance_id: 'i-123')
      expect(instance.status).to be == :shutting_down
    end

    it 'should check if an instance is terminated' do
      mock_instance = Hailstorm::Behavior::AwsAdaptable::Instance.new(
        state: Hailstorm::Behavior::AwsAdaptable::InstanceState.new(name: 'terminated')
      )

      allow(mock_instance).to receive(:terminated?).and_return(true)
      expect(@client).to receive(:find).and_return(mock_instance)
      expect(@client.terminated?(instance_id: 'i-1234')).to be true
    end

    it 'should create an instance' do
      instance_attrs = {
        instance_id: 'i-123456', state: { name: 'pending', code: 10 }, public_ip_address: nil, private_ip_address: nil
      }

      expect(@mock_ec2).to receive(:run_instances).with(image_id: 'ami-1',
                                                        key_name: 's',
                                                        security_group_ids: %w[sg-1],
                                                        instance_type: 't3.small',
                                                        placement: { availability_zone: 'us-east-1a' },
                                                        min_count: 1,
                                                        max_count: 1)
                                                  .and_return(deep_struct(instances: [instance_attrs]))

      resp = deep_struct({ reservations: [{ instances: [instance_attrs] }] })
      allow(@mock_ec2).to receive(:describe_instances).and_return(resp)

      expect(@client.create(image_id: 'ami-1',
                            key_name: 's',
                            security_group_ids: %w[sg-1],
                            instance_type: 't3.small',
                            availability_zone: 'us-east-1a').id).to be == instance_attrs[:instance_id]
    end

    it 'should check if an instance has passed system and instance checks' do
      allow(@mock_ec2).to receive(:describe_instances)
        .and_return(deep_struct(reservations: [
                                  {
                                    instances: [
                                      {
                                        instance_id: 'i-123456', state: { name: 'running', code: 10 },
                                        public_ip_address: '1.2.3.4', private_ip_address: '10.0.0.10'
                                      }
                                    ]
                                  }
                                ]))

      instance_status_resp = deep_struct(
        instance_statuses: [
          {
            system_status: { details: [{ name: 'reachability', status: 'passed' }] },
            instance_status: { details: [{ name: 'reachability', status: 'passed' }] }
          }
        ]
      )

      expect(@mock_ec2).to receive(:describe_instance_status)
        .with(instance_ids: ['i-123456'])
        .and_return(instance_status_resp)

      expect(@client.ready?(instance_id: 'i-123456')).to be true
    end

    it 'should iterate over all instances' do
      stopped_state = { name: 'stopped', code: 10 }
      running_state = { name: 'running', code: 11 }
      terminated_state = { name: 'terminated', code: 12 }
      instances = [
        { state: stopped_state, instance_id: 'id-1', public_ip_address: nil, private_ip_address: nil },
        { state: running_state, instance_id: 'id-2', public_ip_address: '1.2.3.4', private_ip_address: '10.0.0.10' },
        { state: terminated_state, instance_id: 'id-3', public_ip_address: nil, private_ip_address: nil }
      ]

      allow(@mock_ec2).to receive(:describe_instances).and_return(deep_struct(reservations: [{ instances: instances }]))

      iterator = @client.list
      expect(iterator.next.id).to be == instances[0][:instance_id]
      expect(iterator.next.id).to be == instances[1][:instance_id]
      expect(iterator.next.id).to be == instances[2][:instance_id]
    end

    it 'should retry if describe_instances fails' do
      resp_attrs = deep_struct(
        reservations: [
          {
            instances: [
              {
                instance_id: 'i-1234',
                state: { code: 12_345, name: 'running' },
                public_ip_address: '23.45.67.89',
                private_ip_address: '10.0.1.23'
              }
            ]
          }
        ]
      )

      instance_found_ite = [false, true].each
      allow(@mock_ec2).to receive(:describe_instances) do
        raise(Aws::EC2::Errors::ServiceError.new({}, 'InvalidInstanceIDNotFound')) unless instance_found_ite.next

        resp_attrs
      end

      expect(@mock_ec2).to receive(:describe_instances).twice
      @client.find(instance_id: 'i-1234', wait_seconds: 0)
    end

    it 'should raise when number of retries exceeds max retry count' do
      service_error = Aws::EC2::Errors::ServiceError.new({}, 'InvalidInstanceIDNotFound')
      allow(@mock_ec2).to receive(:describe_instances).and_raise(service_error)

      expect { @client.find(instance_id: 'i-1234', wait_seconds: 0, max_find_tries: 2) }.to raise_error
    end
  end

  context Hailstorm::Support::AwsAdapter::SecurityGroupClient do
    before(:each) do
      @client = Hailstorm::Support::AwsAdapter::SecurityGroupClient.new(ec2_client: @mock_ec2)
    end

    it 'should find by name' do
      resp = deep_struct(security_groups: [{
                           group_name: 'hailstorm',
                           description: 'mock security group',
                           group_id: 'sg-123'
                         }])

      expect(@mock_ec2).to receive(:describe_security_groups).and_return(resp)
      security_group = @client.find(name: 'hailstorm')
      expect(security_group).to_not be_nil
      expect(security_group.group_id).to be == resp.security_groups[0].group_id
    end

    it 'should create a security_group' do
      mock_sec_group = deep_struct(group_id: 'sg-1234')
      expect(@mock_ec2).to receive(:create_security_group).and_return(mock_sec_group)
      actual_sec_group = @client.create(
        name: 'dmz',
        description: 'DMZ security group',
        vpc_id: 'vpc-123'
      )

      expect(actual_sec_group.id).to be == mock_sec_group.group_id
    end

    context '#authorize_ingress' do
      it 'should authorize_ingress to a port from the security_group by default' do
        args = {
          group_id: 'sg-123',
          ip_permissions: [
            {
              ip_protocol: 'tcp',
              from_port: 22,
              to_port: 22,
              user_id_group_pairs: [{ group_id: 'sg-123' }],
              ip_ranges: [{ cidr_ip: nil }]
            }
          ]
        }

        expect(@mock_ec2).to receive(:authorize_security_group_ingress).with(args)

        @client.authorize_ingress(group_id: 'sg-123', protocol: :tcp, port_or_range: 22)
      end

      it 'should authorize_ingress to a port_range from the security_group by default' do
        args = {
          group_id: 'sg-123',
          ip_permissions: [
            {
              ip_protocol: 'tcp',
              from_port: 8000,
              to_port: 9000,
              user_id_group_pairs: [{ group_id: 'sg-123' }],
              ip_ranges: [{ cidr_ip: nil }]
            }
          ]
        }
        expect(@mock_ec2).to receive(:authorize_security_group_ingress).with(args)

        @client.authorize_ingress(group_id: 'sg-123', protocol: :tcp, port_or_range: 8000..9000)
      end

      it 'should authorize_ingress to a port from anywhere' do
        args = {
          group_id: 'sg-123',
          ip_permissions: [
            {
              ip_protocol: 'tcp',
              from_port: 8000,
              to_port: 9000,
              ip_ranges: [{ cidr_ip: '0.0.0.0/0' }]
            }
          ]
        }
        expect(@mock_ec2).to receive(:authorize_security_group_ingress).with(args)

        @client.authorize_ingress(group_id: 'sg-123', protocol: :tcp, port_or_range: 8000..9000, cidr: :anywhere)
      end
    end

    it 'should allow_ping' do
      args = {
        group_id: 'sg-123',
        ip_permissions: [
          {
            ip_protocol: 'icmp',
            from_port: -1,
            to_port: -1,
            ip_ranges: [{ cidr_ip: '0.0.0.0/0' }]
          }
        ]
      }
      expect(@mock_ec2).to receive(:authorize_security_group_ingress).with(args)

      @client.allow_ping(group_id: 'sg-123')
    end

    it 'should list the security groups' do
      resp = deep_struct(security_groups: [{ group_name: 'hailstorm', group_id: 'sg-123' }])
      expect(@mock_ec2).to receive(:describe_security_groups).and_return(resp)
      ite = @client.list
      expect(ite.next.to_h).to include(group_name: 'hailstorm', group_id: 'sg-123')
    end

    it 'should delete a security group' do
      expect(@mock_ec2).to receive(:delete_security_group).with(group_id: 'sg-903004f8')
      @client.delete(group_id: 'sg-903004f8')
    end
  end

  context Hailstorm::Support::AwsAdapter::Ec2Client do
    before(:each) do
      @client = Hailstorm::Support::AwsAdapter::Ec2Client.new(ec2_client: @mock_ec2)
    end

    it 'should find first available zone' do
      resp = deep_struct(availability_zones: [
                           { state: 'unavailable', zone_name: 'us-east-1a', region_name: 'us-east-1' },
                           { state: 'available', zone_name: 'us-east-1b', region_name: 'us-east-1' },
                           { state: 'available', zone_name: 'us-east-1c', region_name: 'us-east-1' }
                         ])

      expect(@mock_ec2).to receive(:describe_availability_zones).and_return(resp)
      expect(@client.first_available_zone).to eq('us-east-1b')
    end

    it 'should find vpc from subnet_id' do
      resp = deep_struct(subnets: [{ vpc_id: 'vpc-123' }])
      expect(@mock_ec2).to receive(:describe_subnets).with(subnet_ids: ['subnet-123']).and_return(resp)
      expect(@client.find_vpc(subnet_id: 'subnet-123')).to be == resp.subnets[0].vpc_id
    end

    it 'should find self owned snapshots' do
      resp = deep_struct(snapshots: [
                           { snapshot_id: 'snap-12345def0', state: 'pending' },
                           { snapshot_id: 'snap-67890abc0', state: 'completed' }
                         ])

      expect(@mock_ec2).to receive(:describe_snapshots).with(owner_ids: ['self']).and_return(resp)
      snapshots = @client.find_self_owned_snapshots
      [
        { id: 'snap-12345def0', status: :pending },
        { id: 'snap-67890abc0', status: :completed }
      ].each do |attrs|
        snapshot = snapshots.next
        expect(snapshot.id).to be == attrs[:id]
        expect(snapshot.status).to be == attrs[:status]
      end
    end

    it 'should delete a snapshot' do
      expect(@mock_ec2).to receive(:delete_snapshot).with(snapshot_id: 'snap-123')
      @client.delete_snapshot(snapshot_id: 'snap-123')
    end
  end

  context Hailstorm::Support::AwsAdapter::AmiClient do
    before(:each) do
      @client = Hailstorm::Support::AwsAdapter::AmiClient.new(ec2_client: @mock_ec2)
    end

    it 'should find the first instance of a self owned ami that matches a given pattern' do
      resp = deep_struct(
        images: [
          {
            state: :available, name: 'hailstorm/vulcan', image_id: 'ami-123', state_reason: { code: '12', message: '' }
          },
          {
            state: :available, name: 'hailstorm/vulcan-2', image_id: 'ami-2', state_reason: { code: '12', message: '' }
          },
          {
            state: :available, name: 'hailstorm/romulan-1', image_id: 'ami-3', state_reason: { code: '12', message: '' }
          }
        ]
      )

      expect(@mock_ec2).to receive(:describe_images).with(owners: %w[self]).and_return(resp)
      actual_ami = @client.find_self_owned(ami_name_regexp: Regexp.compile('vulcan'))
      expect(actual_ami.id).to eq(resp.images[0].image_id)
    end

    it 'should select all AMIs matching a given pattern' do
      resp = deep_struct(
        images: [
          {
            state: :available, name: 'hailstorm/vulcan-1', image_id: 'ami-1', state_reason: { code: '12', message: '' }
          },
          {
            state: :available, name: 'hailstorm/vulcan-2', image_id: 'ami-2', state_reason: { code: '12', message: '' }
          },
          {
            state: :available, name: 'hailstorm/romulan-1', image_id: 'ami-3', state_reason: { code: '12', message: '' }
          }
        ]
      )

      expect(@mock_ec2).to receive(:describe_images).with(owners: %w[self]).and_return(resp)
      matched_amis = @client.select_self_owned(ami_name_regexp: Regexp.compile('vulcan'))
      expect(matched_amis.map(&:id)).to contain_exactly('ami-1', 'ami-2')
    end

    it 'should register an instance as a new AMI' do
      image_id = 'ami-123'
      allow(@mock_ec2).to receive(:create_image).and_return(deep_struct(image_id: image_id))
      actual_ami_id = @client.register_ami(
        name: 'hailstorm/brave',
        instance_id: 'i-67678',
        description: 'AMI for distributed performance testing with Hailstorm'
      )

      expect(actual_ami_id).to eql(image_id)
    end

    it 'should query for image availability' do
      resp = {
        images: [
          { image_id: 'ami-123', state: 'available', state_reason: { code: '12', message: '' }, name: 'hailstorm' }
        ]
      }

      expect(@mock_ec2).to receive(:describe_images).with(image_ids: ['ami-123'])
                                                    .and_return(deep_struct(resp))

      expect(@client.available?(ami_id: 'ami-123')).to be true
    end

    it 'should deregister an AMI' do
      expect(@mock_ec2).to receive(:deregister_image).with(image_id: 'ami-123')
      @client.deregister(ami_id: 'ami-123')
    end

    it 'should find an AMI by ami_id' do
      resp = {
        images: [
          { image_id: 'ami-123', state: 'available', name: 'hailstorm', state_reason: { code: '12', message: '' } }
        ]
      }
      expect(@mock_ec2).to receive(:describe_images).with(image_ids: ['ami-123'])
                                                    .and_return(deep_struct(resp))

      expect(@client.find(ami_id: 'ami-123').id).to be == 'ami-123'
    end
  end

  context Hailstorm::Support::AwsAdapter::SubnetClient do
    before(:each) do
      @client = Hailstorm::Support::AwsAdapter::SubnetClient.new(ec2_client: @mock_ec2)
    end

    it 'should find a subnet by name tag' do
      expect(@mock_ec2).to receive(:describe_subnets)
        .with(filters: [{ name: 'tag:Name', values: ['hailstorm'] }])
        .and_return(deep_struct(subnets: [{ subnet_id: 'subnet-123', state: 'pending' }]))

      expect(@client.find(name_tag: 'hailstorm')).to be == 'subnet-123'
    end

    it 'should query its status' do
      expect(@mock_ec2).to receive(:describe_subnets)
        .with(subnet_ids: ['subnet-123'])
        .and_return(deep_struct(subnets: [{ subnet_id: 'subnet-123', state: 'available' }]))

      expect(@client.available?(subnet_id: 'subnet-123')).to be true
    end

    it 'should create a Subnet' do
      expect(@mock_ec2).to receive(:create_subnet).with(cidr_block: '10.0.0.0/16', vpc_id: 'vpc-a01106c2')
                                                  .and_return(deep_struct(subnet: { subnet_id: 'subnet-9d4a7b6c' }))

      expect(@client.create(vpc_id: 'vpc-a01106c2', cidr: '10.0.0.0/16')).to be == 'subnet-9d4a7b6c'
    end

    it 'should modify subnet attribute' do
      expect(@mock_ec2).to receive(:modify_subnet_attribute)
        .with(
          subnet_id: 'subnet-1a2b3c4d',
          map_public_ip_on_launch: { value: true },
          map_customer_owned_ip_on_launch: { value: false }
        )

      @client.modify_attribute(
        subnet_id: 'subnet-1a2b3c4d',
        map_public_ip_on_launch: true,
        map_customer_owned_ip_on_launch: false
      )
    end
  end

  context Hailstorm::Support::AwsAdapter::VpcClient do
    before(:each) do
      @client = Hailstorm::Support::AwsAdapter::VpcClient.new(ec2_client: @mock_ec2)
    end

    it 'should modify vpc attribute' do
      expect(@mock_ec2).to receive(:modify_vpc_attribute)
        .with(vpc_id: 'vpc-123456', enable_dns_hostnames: { value: true })

      @client.modify_attribute(vpc_id: 'vpc-123456', enable_dns_hostnames: true)

      expect(@mock_ec2).to receive(:modify_vpc_attribute)
        .with(vpc_id: 'vpc-123456', enable_dns_support: { value: true })

      @client.modify_attribute(vpc_id: 'vpc-123456', enable_dns_support: true)
    end

    it 'should query its status' do
      expect(@mock_ec2).to receive(:describe_vpcs)
        .with(vpc_ids: ['vpc-a01106c2'])
        .and_return(deep_struct(vpcs: [{ state: 'available' }]))

      expect(@client.available?(vpc_id: 'vpc-a01106c2')).to be true
    end

    it 'should create a VPC' do
      expect(@mock_ec2).to receive(:create_vpc)
        .with(cidr_block: '10.0.0.0/16')
        .and_return(deep_struct(vpc: { vpc_id: 'vpc-a01106c2', state: 'pending' }))

      expect(@client.create(cidr: '10.0.0.0/16')).to be == 'vpc-a01106c2'
    end
  end

  context Hailstorm::Support::AwsAdapter::InternetGatewayClient do
    before(:each) do
      @client = Hailstorm::Support::AwsAdapter::InternetGatewayClient.new(ec2_client: @mock_ec2)
    end

    it 'should attach to a VPC' do
      expect(@mock_ec2).to receive(:attach_internet_gateway).with(vpc_id: 'vpc-123',
                                                                  internet_gateway_id: 'igw-c0a643a9')
      @client.attach(igw_id: 'igw-c0a643a9', vpc_id: 'vpc-123')
    end

    it 'should create an Internet Gateway' do
      resp = deep_struct(internet_gateway: { internet_gateway_id: 'igw-c0a643a9' })
      allow(@mock_ec2).to receive(:create_internet_gateway).and_return(resp)
      expect(@client.create).to be == 'igw-c0a643a9'
    end
  end

  context Hailstorm::Support::AwsAdapter::RouteTableClient do
    before(:each) do
      @client = Hailstorm::Support::AwsAdapter::RouteTableClient.new(ec2_client: @mock_ec2)
    end

    it 'should create a route' do
      expect(@mock_ec2).to receive(:create_route)
        .with(destination_cidr_block: '0.0.0.0/0',
              gateway_id: 'igw-c0a643a9',
              route_table_id: 'rtb-22574640')

      @client.create_route(cidr: '0.0.0.0/0',
                           internet_gateway_id: 'igw-c0a643a9',
                           route_table_id: 'rtb-22574640')
    end

    it 'should associate with a subnet' do
      expect(@mock_ec2).to receive(:associate_route_table)
        .with(route_table_id: 'rtb-123', subnet_id: 'subnet-123')
        .and_return(deep_struct(association_id: 'rtbassoc-781d0d1a'))

      association_id = @client.associate_with_subnet(route_table_id: 'rtb-123', subnet_id: 'subnet-123')
      expect(association_id).to be == 'rtbassoc-781d0d1a'
    end

    it 'should fetch main route table for a VPC' do
      route_tables = [
        {
          associations: [{ main: true, route_table_id: 'rtb-1f382e7d' }],
          route_table_id: 'rtb-1f382e7d'
        },
        {
          associations: [{ main: false, route_table_id: 'rtb-1g473f6f' }],
          route_table_id: 'rtb-1g473f6f'
        }
      ]

      resp = deep_struct(route_tables: route_tables)
      expect(@mock_ec2).to receive(:describe_route_tables).with(filters: [{ name: 'vpc-id', values: ['vpc-123'] }])
                                                          .and_return(resp)

      expect(@client.main_route_table(vpc_id: 'vpc-123')).to be == 'rtb-1f382e7d'
    end

    it 'should fetch all routes in a route_table' do
      expect(@mock_ec2).to receive(:describe_route_tables)
        .with(route_table_ids: ['rtb-1f382e7d'])
        .and_return(
          deep_struct(
            route_tables: [
              { routes: [{ destination_cidr_block: '10.0.0.0/16', gateway_id: 'local', state: 'active' }] }
            ]
          )
        )

      routes = @client.routes(route_table_id: 'rtb-1f382e7d')
      expect(routes.first).to be_active
    end

    it 'should create a route table' do
      response = deep_struct(route_table: { route_table_id: 'rtb-22574640' })
      expect(@mock_ec2).to receive(:create_route_table).with(vpc_id: 'vpc-a01106c2').and_return(response)
      expect(@client.create(vpc_id: 'vpc-a01106c2')).to be == 'rtb-22574640'
    end
  end

  it 'should create clients' do
    factory = Hailstorm::Support::AwsAdapter.clients(
      { access_key_id: 'A', secret_access_key: 's', region: 'us-east-1' }
    )

    factory.members.each do |member|
      client = factory.send(member)
      expect(client).to be_an_instance_of(Hailstorm::Support::AwsAdapter::ExceptionTranslationProxy)
      expect(client.ec2).to_not be_nil
    end

    expect(factory.ec2_client.ec2.config.retry_base_delay).to be > 0.3
    expect(factory.ec2_client.ec2.config.retry_limit).to be >= 3
  end

  context Hailstorm::Support::AwsAdapter::AbstractClient do
    it 'should tag a resource by name' do
      any_client = Hailstorm::Support::AwsAdapter::AbstractClient.new(ec2_client: @mock_ec2)
      expect(@mock_ec2).to receive(:create_tags).with(resources: ['i-123'], tags: [{ key: 'Name', value: 'Agent 1' }])
      any_client.tag_name(resource_id: 'i-123', name: 'Agent 1')
    end
  end

  context Hailstorm::Support::AwsAdapter::ExceptionTranslationProxy do
    it 'should transfer all methods to target' do
      target = double('Target', foo: 1)
      proxy = Hailstorm::Support::AwsAdapter::ExceptionTranslationProxy.new(target)
      expect(proxy.foo).to be == target.foo
    end

    it 'should translate an AWS client or service error' do
      target = double('Target')
      service_error = Aws::Errors::ServiceError.new({}, 'mock error')
      allow(target).to receive(:foo).and_raise(service_error)
      proxy = Hailstorm::Support::AwsAdapter::ExceptionTranslationProxy.new(target)
      expect { proxy.foo }.to raise_error(Hailstorm::AwsException)
    end

    it 'should not translate an error if its not an AWS client or service error' do
      target = double('Target')
      allow(target).to receive(:foo).and_raise(ArgumentError)
      proxy = Hailstorm::Support::AwsAdapter::ExceptionTranslationProxy.new(target)
      expect { proxy.foo }.to raise_error(ArgumentError)
    end
  end
end
