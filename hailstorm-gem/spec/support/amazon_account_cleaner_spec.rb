require 'spec_helper'
require 'hailstorm/support/amazon_account_cleaner'

describe Hailstorm::Support::AmazonAccountCleaner do

  before(:each) do
    @account_cleaner = Hailstorm::Support::AmazonAccountCleaner.new(access_key_id: 'A',
                                                                    secret_access_key: 'B',
                                                                    doze_seconds: 0)
  end

  it 'clean an AWS account of Hailstorm artifacts' do
    @account_cleaner.should_receive(:terminate_instances)
    @account_cleaner.should_receive(:deregister_amis)
    @account_cleaner.should_receive(:delete_snapshots)
    @account_cleaner.should_receive(:delete_security_groups)
    @account_cleaner.should_receive(:delete_key_pairs)
    @account_cleaner.stub!(:ec2_adapter).and_return(Hailstorm::Support::AwsAdapter::EC2)

    expect(@account_cleaner.send(:regions)).to_not be_empty
    @account_cleaner.cleanup(true, ['us-east-1'])
  end

  context '#terminate_instances' do
    it 'should terminate all instances' do
      instances = [
        {status: [:stopped, :terminated].each, id: 'id-1'},
        {status: [:running, :terminated].each, id: 'id-2'},
        {status: :terminated, id: 'id-3'},
      ].map do |attrs|
        instance = mock(Hailstorm::Support::AwsAdapter::EC2::Instance, id: attrs[:id])
        instance.stub!(:status) do
          attrs[:status].is_a?(Enumerator) ? attrs[:status].next : attrs[:status]
        end

        instance
      end

      instances[0].should_receive(:terminate)
      instances[1].should_receive(:terminate)
      instances[2].should_not_receive(:terminate)
      ec2 = mock(Hailstorm::Support::AwsAdapter::EC2)
      ec2.stub!(:all_instances).and_return(instances.each)

      @account_cleaner.send(:terminate_instances, ec2)
    end
  end

  context '#deregister_amis' do
    it 'should deregister all owned AMIs' do
      images = [
        {state: :pending, id: 'ami-1'},
        {state: :available, id: 'ami-2'}
      ].map do |attrs|
        mock(Hailstorm::Support::AwsAdapter::EC2::Image, id: attrs[:id], state: attrs[:state])
      end

      images[0].should_not_receive(:deregister)
      images[1].should_receive(:deregister)
      ec2 = mock(Hailstorm::Support::AwsAdapter::EC2)
      ec2.stub!(:find_self_owned_ami).and_return(images)

      @account_cleaner.send(:deregister_amis, ec2)
    end
  end

  context '#delete_snapshots' do
    it 'should delete all owned snapshots' do
      snapshots = [
        {status: :pending, id: 'snap-1'},
        {status: :completed, id: 'snap-2'}
      ].map do |attrs|
        mock(Hailstorm::Support::AwsAdapter::EC2::Snapshot, id: attrs[:id], status: attrs[:status])
      end

      snapshots[0].should_not_receive(:delete)
      snapshots[1].should_receive(:delete)
      ec2 = mock(Hailstorm::Support::AwsAdapter::EC2)
      ec2.stub!(:find_self_owned_snapshots).and_return(snapshots.each)

      @account_cleaner.send(:delete_snapshots, ec2)
    end
  end

  context '#delete_key_pairs' do
    it 'should delete key_pairs' do
      key_pair = mock(Hailstorm::Support::AwsAdapter::EC2::KeyPair, name: 's')
      key_pair.should_receive(:delete)
      ec2 = mock(Hailstorm::Support::AwsAdapter::EC2)
      ec2.stub!(:all_key_pairs).and_return([key_pair].each)
      @account_cleaner.send(:delete_key_pairs, ec2)
    end
  end

  context '#delete_security_groups' do
    it 'should delete default Hailstorm security group' do
      sec_group = mock(Hailstorm::Support::AwsAdapter::EC2::SecurityGroup,
                       name: Hailstorm::Model::AmazonCloud::Defaults::SECURITY_GROUP)
      sec_group.should_receive(:delete)
      ec2 = mock(Hailstorm::Support::AwsAdapter::EC2)
      ec2.stub!(:all_security_groups).and_return([sec_group].each)
      @account_cleaner.send(:delete_security_groups, ec2)
    end
  end
end
