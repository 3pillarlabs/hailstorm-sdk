# frozen_string_literal: true

require 'spec_helper'
require 'hailstorm/model/helper/ec2_instance_helper'
require 'hailstorm/model/amazon_cloud'

describe Hailstorm::Model::Helper::Ec2InstanceHelper do
  before(:each) do
    @mock_instance = Hailstorm::Behavior::AwsAdaptable::Instance.new(
      instance_id: 'A',
      state: Hailstorm::Behavior::AwsAdaptable::InstanceState.new(name: 'pending'),
      public_ip_address: nil,
      private_ip_address: nil
    )

    mock_instance_client = instance_double(Hailstorm::Behavior::AwsAdaptable::InstanceClient, create: @mock_instance)
    allow(mock_instance_client).to receive(:find).and_return(@mock_instance)
    allow(mock_instance_client).to receive(:ready?).and_return(true)
    mock_aws = Hailstorm::Model::AmazonCloud.new(ssh_identity: 'hailstorm',
                                                 user_name: 'ubuntu',
                                                 vpc_subnet_id: 'subnet-123',
                                                 instance_type: 't3.large',
                                                 region: 'us-east-2',
                                                 zone: 'us-east-2a')
    allow(mock_aws).to receive(:ssh_options).and_return({})
    @helper = Hailstorm::Model::Helper::Ec2InstanceHelper.new(instance_client: mock_instance_client,
                                                              aws_clusterable: mock_aws)
  end

  context 'when ec2 instance is ready' do
    it 'should return clean_instance' do
      allow(@helper).to receive(:ensure_ssh_connectivity).and_return(true)
      instance = @helper.create_ec2_instance(ami_id: 'ami-123', security_group_ids: 'sg-123')
      expect(instance).to eql(@mock_instance)
    end

    it 'should raise error if ssh connectivity fails' do
      allow(Hailstorm::Support::SSH).to receive(:ensure_connection).and_return(false)
      expect do
        @helper.create_ec2_instance(ami_id: 'ami-123',
                                    security_group_ids: 'sg-123')
      end.to raise_error(Hailstorm::Exception)
    end
  end

  context 'instance creation failed' do
    it 'should raise error' do
      allow(@helper.instance_client).to receive(:ready?).and_return(false)
      allow(@helper).to receive(:wait_for).and_raise(Hailstorm::Exception, 'mock error')
      expect do
        @helper.create_ec2_instance(ami_id: 'ami-123',
                                    security_group_ids: 'sg-123')
      end.to raise_error(Hailstorm::Exception)
    end
  end
end
