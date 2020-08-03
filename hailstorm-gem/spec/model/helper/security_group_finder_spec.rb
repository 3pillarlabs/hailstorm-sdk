require 'spec_helper'
require 'hailstorm/model/helper/security_group_finder'

describe Hailstorm::Model::Helper::SecurityGroupFinder do

  it 'should find the security group if vpc_id is provided' do
    mock_sec_group = Hailstorm::Behavior::AwsAdaptable::SecurityGroup.new(group_id: 'sg-a1')
    mock_sg_client = mock(Hailstorm::Behavior::AwsAdaptable::SecurityGroupClient)
    mock_sg_client.stub!(:find).and_return(mock_sec_group)

    finder = Hailstorm::Model::Helper::SecurityGroupFinder.new(security_group: 'hailstorm',
                                                               security_group_client: mock_sg_client)
    expect(finder.find_security_group(vpc_id: 'vpc-123')).to be == mock_sec_group
  end

  it 'should find the security group if vpc_subnet_id is provided' do
    mock_sec_group = Hailstorm::Behavior::AwsAdaptable::SecurityGroup.new(group_id: 'sg-a1')
    mock_sg_client = mock(Hailstorm::Behavior::AwsAdaptable::SecurityGroupClient)
    mock_sg_client.stub!(:find).and_return(mock_sec_group)
    mock_ec2_client = mock(Hailstorm::Behavior::AwsAdaptable::Ec2Client)
    mock_ec2_client.stub!(:find_vpc).and_return('vpc-123')

    finder = Hailstorm::Model::Helper::SecurityGroupFinder.new(security_group_client: mock_sg_client,
                                                               security_group: 'hailstorm',
                                                               ec2_client: mock_ec2_client,
                                                               vpc_subnet_id: 'subnet-123')
    expect(finder.find_security_group).to be == mock_sec_group
  end

  it 'should find the security group' do
    mock_sec_group = Hailstorm::Behavior::AwsAdaptable::SecurityGroup.new(group_id: 'sg-a1')
    mock_sg_client = mock(Hailstorm::Behavior::AwsAdaptable::SecurityGroupClient)
    mock_sg_client.stub!(:find).and_return(mock_sec_group)

    finder = Hailstorm::Model::Helper::SecurityGroupFinder.new(security_group: 'hailstorm',
                                                               security_group_client: mock_sg_client)
    expect(finder.find_security_group).to be == mock_sec_group
  end
end
