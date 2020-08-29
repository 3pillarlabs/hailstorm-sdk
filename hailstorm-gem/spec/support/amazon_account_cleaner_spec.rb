require 'spec_helper'
require 'hailstorm/support/amazon_account_cleaner'

describe Hailstorm::Support::AmazonAccountCleaner do

  before(:each) do
    @client_factory = Hailstorm::Behavior::AwsAdaptable::ClientFactory.new(
      ec2_client: instance_double(Hailstorm::Behavior::AwsAdaptable::Ec2Client),
      key_pair_client: instance_double(Hailstorm::Behavior::AwsAdaptable::KeyPairClient),
      security_group_client: instance_double(Hailstorm::Behavior::AwsAdaptable::SecurityGroupClient),
      instance_client: instance_double(Hailstorm::Behavior::AwsAdaptable::InstanceClient),
      ami_client: instance_double(Hailstorm::Behavior::AwsAdaptable::AmiClient)
    )

    @account_cleaner = Hailstorm::Support::AmazonAccountCleaner.new(client_factory: @client_factory,
                                                                    region_code: 'us-east-1',
                                                                    doze_seconds: 0)
  end

  it 'clean an AWS account of Hailstorm artifacts' do
    expect(@account_cleaner).to receive(:terminate_instances)
    expect(@account_cleaner).to receive(:deregister_amis)
    expect(@account_cleaner).to receive(:delete_snapshots)
    expect(@account_cleaner).to receive(:delete_security_groups)
    expect(@account_cleaner).to receive(:delete_key_pairs)

    @account_cleaner.cleanup(remove_key_pairs: true)
  end

  context '#terminate_instances' do
    it 'should terminate all instances' do
      instance_state = -> (state) { Hailstorm::Behavior::AwsAdaptable::InstanceState.new(name: state.to_s) }
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
      images = [{ state: 'pending', image_id: 'ami-1' }, { state: 'available', image_id: 'ami-2' }]
                 .map { |attrs| Hailstorm::Behavior::AwsAdaptable::Ami.new(attrs) }

      expect(@client_factory.ami_client).to receive(:deregister).once
      expect(@client_factory.ami_client).to_not receive(:deregister).with(ami_id: 'ami-1')
      allow(@client_factory.ami_client).to receive(:find_self_owned).and_return(images)

      @account_cleaner.send(:deregister_amis)
    end
  end

  context '#delete_snapshots' do
    it 'should delete all owned snapshots' do
      pending_snapshot = Hailstorm::Behavior::AwsAdaptable::Snapshot.new(state: 'pending', snapshot_id: 'snap-1')
      completed_snapshot = Hailstorm::Behavior::AwsAdaptable::Snapshot.new(state: 'completed', snapshot_id: 'snap-2')
      snapshots = [pending_snapshot, completed_snapshot]

      expect(@client_factory.ec2_client).to_not receive(:delete_snapshot).with(snapshot_id: pending_snapshot.id)
      expect(@client_factory.ec2_client).to receive(:delete_snapshot).with(snapshot_id: completed_snapshot.id)
      allow(@client_factory.ec2_client).to receive(:find_self_owned_snapshots).and_return(snapshots.each)

      @account_cleaner.send(:delete_snapshots)
    end
  end

  context '#delete_key_pairs' do
    it 'should delete key_pairs' do
      key_pair_info = Hailstorm::Behavior::AwsAdaptable::KeyPairInfo.new(key_name: 's', key_pair_id: 'kp-123')
      expect(@client_factory.key_pair_client).to receive(:delete).with(key_pair_id: 'kp-123')
      allow(@client_factory.key_pair_client).to receive(:list).and_return([key_pair_info].each)
      @account_cleaner.send(:delete_key_pairs)
    end
  end

  context '#delete_security_groups' do
    it 'should delete default Hailstorm security group' do
      sec_group = Hailstorm::Behavior::AwsAdaptable::SecurityGroup.new(
        group_name: Hailstorm::Model::Helper::AmazonCloudDefaults::SECURITY_GROUP,
        group_id: 'sg-123'
      )

      expect(@client_factory.security_group_client).to receive(:delete).with(group_id: 'sg-123')
      allow(@client_factory.security_group_client).to receive(:list).and_return([sec_group].each)
      @account_cleaner.send(:delete_security_groups)
    end
  end
end
