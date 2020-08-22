require 'spec_helper'
require 'hailstorm/model/helper/vpc_helper'

describe Hailstorm::Model::Helper::VpcHelper do

  it 'should create a Hailstorm public subnet if it does not exist' do
    mock_vpc_client = instance_double(Hailstorm::Behavior::AwsAdaptable::VpcClient)
    allow(mock_vpc_client).to receive(:modify_attribute)
    allow(mock_vpc_client).to receive(:tag_name)
    allow(mock_vpc_client).to receive(:available?).and_return(true)
    allow(mock_vpc_client).to receive(:create).and_return('vpc-123')

    mock_subnet_client = instance_double(Hailstorm::Behavior::AwsAdaptable::SubnetClient)
    allow(mock_subnet_client).to receive(:find).and_return(nil)
    allow(mock_subnet_client).to receive(:tag_name)
    allow(mock_subnet_client).to receive(:available?).and_return(true)
    allow(mock_subnet_client).to receive(:modify_attribute)
    allow(mock_subnet_client).to receive(:create).and_return('subnet-123')

    mock_igw_client = instance_double(Hailstorm::Behavior::AwsAdaptable::InternetGatewayClient)
    allow(mock_igw_client).to receive(:tag_name)
    allow(mock_igw_client).to receive(:attach)
    allow(mock_igw_client).to receive(:create).and_return('igw-123')

    mock_rt_client = instance_double(Hailstorm::Behavior::AwsAdaptable::RouteTableClient)
    allow(mock_rt_client).to receive(:create_route)
    allow(mock_rt_client).to receive(:associate_with_subnet)
    allow(mock_rt_client).to receive(:main_route_table).and_return('route-123')
    route = Hailstorm::Behavior::AwsAdaptable::Route.new(state: 'active')
    allow(mock_rt_client).to receive(:routes).and_return([route])

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
