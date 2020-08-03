require 'spec_helper'
require 'hailstorm/model/helper/ec2_instance_helper'

describe Hailstorm::Model::Helper::Ec2InstanceHelper do
  before(:each) do
    @mock_instance = Hailstorm::Behavior::AwsAdaptable::Instance.new(
        instance_id: 'A',
        state: Hailstorm::Behavior::AwsAdaptable::InstanceState.new(name: 'pending'),
        public_ip_address: nil,
        private_ip_address: nil
    )

    mock_instance_client = mock(Hailstorm::Behavior::AwsAdaptable::InstanceClient, create: @mock_instance)
    mock_instance_client.stub!(:find).and_return(@mock_instance)
    mock_instance_client.stub!(:ready?).and_return(true)
    @helper = Hailstorm::Model::Helper::Ec2InstanceHelper.new(instance_client: mock_instance_client,
                                                              ssh_options: {},
                                                              key_name: 'hailstorm',
                                                              user_name: 'ubuntu',
                                                              vpc_subnet_id: 'subnet-123',
                                                              instance_type: 't3.large',
                                                              region: 'us-east-2',
                                                              zone: 'us-east-2a')
  end

  context 'when ec2 instance is ready' do
    it 'should return clean_instance' do
      @helper.stub!(:ensure_ssh_connectivity).and_return(true)
      instance = @helper.create_ec2_instance(ami_id: 'ami-123', security_group_ids: 'sg-123')
      expect(instance).to eql(@mock_instance)
    end

    it 'should raise error if ssh connectivity fails' do
      Hailstorm::Support::SSH.stub!(:ensure_connection).and_return(false)
      expect { @helper.create_ec2_instance(ami_id: 'ami-123',
                                           security_group_ids: 'sg-123') }.to raise_error(Hailstorm::Exception)
    end
  end

  context 'instance creation failed' do
    it 'should raise error' do
      @helper.instance_client.stub!(:ready?).and_return(false)
      @helper.stub!(:wait_for).and_raise(Hailstorm::Exception, 'mock error')
      expect { @helper.create_ec2_instance(ami_id: 'ami-123',
                                           security_group_ids: 'sg-123') }.to raise_error(Hailstorm::Exception)
    end
  end
end
