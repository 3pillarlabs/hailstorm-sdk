require 'spec_helper'
require 'hailstorm/model/helper/vpc_helper'

describe Hailstorm::Model::Helper::VpcHelper do

  it 'should create a Hailstorm public subnet if it does not exist' do
    mock_vpc_client = mock(Hailstorm::Behavior::AwsAdaptable::VpcClient)
    mock_vpc_client.stub!(:modify_attribute)
    mock_vpc_client.stub!(:tag_name)
    mock_vpc_client.stub!(:available?).and_return(true)
    mock_vpc_client.stub!(:create).and_return('vpc-123')

    mock_subnet_client = mock(Hailstorm::Behavior::AwsAdaptable::SubnetClient)
    mock_subnet_client.stub!(:find).and_return(nil)
    mock_subnet_client.stub!(:tag_name)
    mock_subnet_client.stub!(:available?).and_return(true)
    mock_subnet_client.stub!(:modify_attribute)
    mock_subnet_client.stub!(:create).and_return('subnet-123')

    mock_igw_client = mock(Hailstorm::Behavior::AwsAdaptable::InternetGatewayClient)
    mock_igw_client.stub!(:tag_name)
    mock_igw_client.stub!(:attach)
    mock_igw_client.stub!(:create).and_return('igw-123')

    mock_rt_client = mock(Hailstorm::Behavior::AwsAdaptable::RouteTableClient)
    mock_rt_client.stub!(:create_route)
    mock_rt_client.stub!(:associate_with_subnet)
    mock_rt_client.stub!(:main_route_table).and_return('route-123')
    route = Hailstorm::Behavior::AwsAdaptable::Route.new(state: 'active')
    mock_rt_client.stub!(:routes).and_return([route])

    helper = Hailstorm::Model::Helper::VpcHelper.new(vpc_client: mock_vpc_client,
                                                     subnet_client: mock_subnet_client,
                                                     internet_gateway_client: mock_igw_client,
                                                     route_table_client: mock_rt_client)


    subnet_id = helper.find_or_create_vpc_subnet(subnet_name_tag: 'hailstorm',
                                                 vpc_name_tag: 'hailstorm',
                                                 cidr: '10.0.0.0/10')
    expect(subnet_id).to be == 'subnet-123'
  end
end
