require 'spec_helper'
require 'hailstorm/model/helper/security_group_creator'

describe Hailstorm::Model::Helper::SecurityGroupCreator do

  context 'security group does not exist' do
    it 'should create EC2 security group' do
      mock_sg_client = mock(Hailstorm::Behavior::AwsAdaptable::SecurityGroupClient)
      mock_sg_client.stub!(:find).and_return(nil)
      mock_sec_group = Hailstorm::Behavior::AwsAdaptable::SecurityGroup.new(group_id: 'sg-a1')
      mock_sg_client.stub!(:create).and_return(mock_sec_group)
      mock_sg_client.should_receive(:authorize_ingress).exactly(3).times
      mock_sg_client.should_receive(:allow_ping)
      mock_ec2_client = mock(Hailstorm::Behavior::AwsAdaptable::Ec2Client)
      mock_ec2_client.stub!(:find_vpc).and_return('vpc-123')
      helper = Hailstorm::Model::Helper::SecurityGroupCreator.new(security_group_client: mock_sg_client,
                                                                  security_group_desc: 'Hailstorm',
                                                                  region: 'us-east-1',
                                                                  security_group: 'hailstorm',
                                                                  ssh_port: 22,
                                                                  vpc_subnet_id: 'subnet-123',
                                                                  ec2_client: mock_ec2_client)
      helper.create_security_group
    end
  end
end
