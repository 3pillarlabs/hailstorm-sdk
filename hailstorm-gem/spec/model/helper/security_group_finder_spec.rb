require 'spec_helper'
require 'hailstorm/model/helper/security_group_finder'
require 'hailstorm/model/amazon_cloud'

describe Hailstorm::Model::Helper::SecurityGroupFinder do
  before(:each) do
    @mock_sec_group = Hailstorm::Behavior::AwsAdaptable::SecurityGroup.new(group_id: 'sg-a1')
    @mock_sg_client = instance_double(Hailstorm::Behavior::AwsAdaptable::SecurityGroupClient)
    allow(@mock_sg_client).to receive(:find).and_return(@mock_sec_group)
    @mock_aws = Hailstorm::Model::AmazonCloud.new(security_group: 'hailstorm')
  end

  it 'should find the security group if vpc_id is provided' do
    finder = Hailstorm::Model::Helper::SecurityGroupFinder.new(aws_clusterable: @mock_aws,
                                                               security_group_client: @mock_sg_client)
    expect(finder.find_security_group(vpc_id: 'vpc-123')).to be == @mock_sec_group
  end

  it 'should find the security group if vpc_subnet_id is provided' do
    @mock_aws.vpc_subnet_id = 'subnet-123'
    mock_ec2_client = instance_double(Hailstorm::Behavior::AwsAdaptable::Ec2Client)
    allow(mock_ec2_client).to receive(:find_vpc).and_return('vpc-123')
    finder = Hailstorm::Model::Helper::SecurityGroupFinder.new(security_group_client: @mock_sg_client,
                                                               ec2_client: mock_ec2_client,
                                                               aws_clusterable: @mock_aws)
    expect(finder.find_security_group).to be == @mock_sec_group
  end

  it 'should find the security group' do
    finder = Hailstorm::Model::Helper::SecurityGroupFinder.new(aws_clusterable: @mock_aws,
                                                               security_group_client: @mock_sg_client)
    expect(finder.find_security_group).to be == @mock_sec_group
  end
end
