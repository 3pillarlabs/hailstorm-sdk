# frozen_string_literal: true

require 'spec_helper'
require 'hailstorm/support/amazon_account_cleaner'

describe Hailstorm::Support::AmazonAccountCleaner do
  before(:each) do
    @client_factory = Hailstorm::Behavior::AwsAdaptable::ClientFactory.new(
      ec2_client: instance_double(Hailstorm::Behavior::AwsAdaptable::Ec2Client, 'ec2_client'),
      key_pair_client: instance_double(Hailstorm::Behavior::AwsAdaptable::KeyPairClient, 'key_pair_client'),
      security_group_client: instance_double(Hailstorm::Behavior::AwsAdaptable::SecurityGroupClient,
                                             'security_group_client'),
      instance_client: instance_double(Hailstorm::Behavior::AwsAdaptable::InstanceClient, 'instance_client'),
      ami_client: instance_double(Hailstorm::Behavior::AwsAdaptable::AmiClient, 'ami_client'),
      route_table_client: instance_double(Hailstorm::Behavior::AwsAdaptable::RouteTableClient, 'route_table_client'),
      internet_gateway_client: instance_double(Hailstorm::Behavior::AwsAdaptable::InternetGatewayClient,
                                               'internet_gateway_client')
    )

    @resource_group = Hailstorm::Support::AmazonAccountCleaner::AccountResourceGroup.new(
      instance_ids: %w[id-1 id-2 id-3],
      ami_id: 'ami-123',
      vpc_id: 'vpc-123',
      security_group_name: 'hailstorm',
      key_pair_name: 'secure',
      subnet_id: 'subnet-123'
    )

    @account_cleaner = Hailstorm::Support::AmazonAccountCleaner.new(client_factory: @client_factory,
                                                                    region_code: 'us-east-1',
                                                                    resource_group: @resource_group,
                                                                    doze_seconds: 0)
  end

  it 'clean an AWS account of Hailstorm artifacts' do
    expect(@account_cleaner).to receive(:terminate_instances)
    expect(@account_cleaner).to receive(:deregister_amis)
    expect(@account_cleaner).to receive(:delete_security_groups)
    expect(@account_cleaner).to receive(:delete_key_pairs)
    expect(@account_cleaner).to receive(:delete_subnet)
    expect(@account_cleaner).to receive(:delete_vpc)

    @account_cleaner.cleanup
  end

  context 'when interim steps fail' do
    it 'should throw an exception with information on skipped steps' do
      allow(@account_cleaner).to receive(:deregister_amis).and_raise(Hailstorm::AwsException, 'mock error')
      allow(@client_factory.instance_client).to receive(:list).and_return([])
      expect(@account_cleaner).to receive(:delete_key_pairs)
      begin
        @account_cleaner.cleanup
        raise('Control should not reach here')
      rescue Hailstorm::AwsException => error
        expect(error.message).to be == 'mock error. All remaining steps were skipped.'
        expect(error.data).to be == %i[deregister_amis delete_security_groups delete_subnet delete_vpc]
      end

      expect(@account_cleaner).to_not receive(:delete_subnet)
      expect(@account_cleaner).to_not receive(:delete_vpc)
    end
  end

  context '#terminate_instances' do
    it 'should terminate all instances' do
      instance_state = ->(state) { Hailstorm::Behavior::AwsAdaptable::InstanceState.new(name: state.to_s) }
      stopped_attrs = { state: instance_state.call(:stopped),
                        instance_id: 'id-1',
                        public_ip_address: nil,
                        private_ip_address: nil }

      running_attrs = { state: instance_state.call(:running),
                        instance_id: 'id-2',
                        public_ip_address: '1.2.3.4',
                        private_ip_address: '10.0.1.80' }

      terminated_attrs = { state: instance_state.call(:terminated),
                           instance_id: 'id-3',
                           public_ip_address: nil,
                           private_ip_address: nil }

      instances = [stopped_attrs, running_attrs, terminated_attrs].map do |attrs|
        Hailstorm::Behavior::AwsAdaptable::Instance.new(attrs)
      end

      expect(@client_factory.instance_client).to receive(:terminate).twice
      expect(@client_factory.instance_client).to_not receive(:terminate).with(instance_id: 'id-3')
      allow(@client_factory.instance_client).to receive(:list).and_return(instances.each)
      allow(@client_factory.instance_client).to receive(:terminated?).and_return(true)
      @account_cleaner.send(:terminate_instances)
    end
  end

  context '#deregister_amis' do
    it 'should deregister all owned AMIs' do
      expect(@client_factory.ami_client).to receive(:deregister).with(ami_id: 'ami-2')
      expect(@client_factory.ec2_client).to receive(:delete_snapshot).with(snapshot_id: 'snap-2')
      image = Hailstorm::Behavior::AwsAdaptable::Ami.new(state: 'available', image_id: 'ami-2', snapshot_id: 'snap-2')
      allow(@client_factory.ami_client).to receive(:find).and_return(image)

      @account_cleaner.send(:deregister_amis)
    end
  end

  context '#delete_key_pairs' do
    it 'should delete key_pairs' do
      key_pair_info = Hailstorm::Behavior::AwsAdaptable::KeyPairInfo.new(
        key_name: @resource_group.key_pair_name,
        key_pair_id: 'kp-123'
      )

      expect(@client_factory.key_pair_client).to receive(:delete).with(key_pair_id: 'kp-123')
      allow(@client_factory.key_pair_client).to receive(:find).and_return(key_pair_info.key_pair_id)
      @account_cleaner.send(:delete_key_pairs)
    end
  end

  context '#delete_security_groups' do
    it 'should delete default Hailstorm security group' do
      sec_group = Hailstorm::Behavior::AwsAdaptable::SecurityGroup.new(
        group_name: @resource_group.security_group_name,
        group_id: 'sg-123'
      )

      expect(@client_factory.security_group_client).to receive(:delete).with(group_id: 'sg-123')
      allow(@client_factory.security_group_client).to receive(:find).and_return(sec_group)
      @account_cleaner.send(:delete_security_groups)
    end
  end

  context '#delete_subnet' do
    it 'should delete a Hailstorm tagged subnet' do
      expect(@client_factory.subnet_client).to receive(:delete)
      allow(@client_factory.subnet_client).to receive(:find).and_return('subnet-123')
      @account_cleaner.send(:delete_subnet)
    end
  end

  context '#delete_vpc' do
    it 'should delete a Hailstorm tagged vpc' do
      vpc = Hailstorm::Behavior::AwsAdaptable::Vpc.new(vpc_id: 'vpc-123', state: 'available')
      expect(@client_factory.vpc_client).to receive(:delete)
      allow(@client_factory.vpc_client).to receive(:find).and_return(vpc)
      allow(@account_cleaner).to receive(:delete_routing_tables)
      allow(@account_cleaner).to receive(:delete_internet_gateways)
      @account_cleaner.send(:delete_vpc)
    end
  end

  context '#delete_routing_tables' do
    it 'should delete routing tables created by Hailstorm in a VPC' do
      main_rtb = Hailstorm::Behavior::AwsAdaptable::RouteTable.new(id: 'rtb-123', main: true)
      secondary_rtb = Hailstorm::Behavior::AwsAdaptable::RouteTable.new(id: 'rtb-456', main: false)
      expect(@client_factory.route_table_client).to receive(:route_tables).and_return([main_rtb, secondary_rtb])
      expect(@client_factory.route_table_client).to_not receive(:delete).with(route_table_id: main_rtb.id)
      expect(@client_factory.route_table_client).to receive(:delete).with(route_table_id: secondary_rtb.id)
      @account_cleaner.send(:delete_routing_tables)
    end
  end

  context '#delete_internet_gateways' do
    it 'should delete internet gateways created by Hailstorm in a VPC' do
      igw = Hailstorm::Behavior::AwsAdaptable::InternetGateway.new(id: 'igw-123')
      expect(@client_factory.internet_gateway_client).to receive(:select).and_return([igw])
      expect(@client_factory.internet_gateway_client).to receive(:delete).with(igw_id: igw.id)
      expect(@client_factory.internet_gateway_client).to receive(:detach_from_vpc)
      @account_cleaner.send(:delete_internet_gateways)
    end
  end
end
