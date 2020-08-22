require 'spec_helper'
require 'hailstorm/model/helper/security_group_creator'
require 'hailstorm/model/amazon_cloud'

describe Hailstorm::Model::Helper::SecurityGroupCreator do

  context 'security group does not exist' do
    it 'should create EC2 security group' do
      mock_sg_client = instance_double(Hailstorm::Behavior::AwsAdaptable::SecurityGroupClient)
      allow(mock_sg_client).to receive(:find).and_return(nil)
      mock_sec_group = Hailstorm::Behavior::AwsAdaptable::SecurityGroup.new(group_id: 'sg-a1')
      allow(mock_sg_client).to receive(:create).and_return(mock_sec_group)
      expect(mock_sg_client).to receive(:authorize_ingress).exactly(3).times
      expect(mock_sg_client).to receive(:allow_ping)
      mock_ec2_client = instance_double(Hailstorm::Behavior::AwsAdaptable::Ec2Client)
      allow(mock_ec2_client).to receive(:find_vpc).and_return('vpc-123')
      mock_aws = Hailstorm::Model::AmazonCloud.new(region: 'us-east-1',
                                                   security_group: 'hailstorm',
                                                   ssh_port: 22,
                                                   vpc_subnet_id: 'subnet-123')
      helper = Hailstorm::Model::Helper::SecurityGroupCreator.new(security_group_client: mock_sg_client,
                                                                  aws_clusterable: mock_aws,
                                                                  ec2_client: mock_ec2_client)
      helper.create_security_group
    end
  end
end
