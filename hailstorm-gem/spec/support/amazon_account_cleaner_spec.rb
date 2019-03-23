require 'spec_helper'
require 'hailstorm/support/amazon_account_cleaner'
require 'aws'

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

    expect(@account_cleaner.send(:regions)).to_not be_empty
    @account_cleaner.cleanup(true, ['us-east-1'])
  end

  context '#terminate_instances' do
    it 'should terminate all instances' do
      instances = [
        {status: :stopped, id: 'id-1'},
        {status: [:running, :terminated].each, id: 'id-2'}
      ].map do |attrs|
        instance = mock(AWS::EC2::Instance, id: attrs[:id])
        instance.stub!(:status) do
          attrs[:status].is_a?(Enumerator) ? attrs[:status].next : attrs[:status]
        end
        instance
      end

      instances[0].should_not_receive(:terminate)
      instances[1].should_receive(:terminate)
      ec2 = mock(AWS::EC2)
      ec2.stub!(:instances).and_return(instances)

      @account_cleaner.send(:terminate_instances, ec2)
    end
  end

  context '#deregister_amis' do
    it 'should deregister all owned AMIs' do
      images = [
        {state: :pending, id: 'ami-1'},
        {state: :available, id: 'ami-2'}
      ].map do |attrs|
        mock(AWS::EC2::Image, id: attrs[:id], state: attrs[:state])
      end

      images[0].should_not_receive(:deregister)
      images[1].should_receive(:deregister)
      ec2 = mock(AWS::EC2)
      ec2.stub_chain(:images, :with_owner).and_return(images)

      @account_cleaner.send(:deregister_amis, ec2)
    end
  end

  context '#delete_snapshots' do
    it 'should delete all owned snapshots' do
      snapshots = [
        {status: :pending, id: 'snap-1'},
        {status: :completed, id: 'snap-2'}
      ].map do |attrs|
        mock(AWS::EC2::Snapshot, id: attrs[:id], status: attrs[:status])
      end

      snapshots[0].should_not_receive(:delete)
      snapshots[1].should_receive(:delete)
      ec2 = mock(AWS::EC2)
      ec2.stub_chain(:snapshots, :with_owner).and_return(snapshots)

      @account_cleaner.send(:delete_snapshots, ec2)
    end
  end

  context '#delete_key_pairs' do
    it 'should delete key_pairs' do
      key_pair = mock(AWS::EC2::KeyPair, name: 's')
      key_pair.should_receive(:delete)
      ec2 = mock(AWS::EC2)
      ec2.stub!(:key_pairs).and_return([key_pair])
      @account_cleaner.send(:delete_key_pairs, ec2)
    end
  end

  context '#delete_security_groups' do
    it 'should delete default Hailstorm security group' do
      sec_group = mock(AWS::EC2::SecurityGroup, name: Hailstorm::Model::AmazonCloud::Defaults::SECURITY_GROUP)
      sec_group.should_receive(:delete)
      ec2 = mock(AWS::EC2)
      ec2.stub!(:security_groups).and_return([sec_group])
      @account_cleaner.send(:delete_security_groups, ec2)
    end
  end
end
