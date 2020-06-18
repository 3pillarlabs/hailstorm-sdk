require 'spec_helper'
require 'hailstorm/support/aws_adapter'

describe Hailstorm::Support::AwsAdapter do
  before(:each) do
    mock_ec2 = mock(AWS::EC2)
    @aws_adapter = Hailstorm::Support::AwsAdapter::EC2.new({}, ec2: mock_ec2)
  end

  it 'should initialize the EC2 adapter' do
    mock_ec2 = mock(AWS::EC2)
    mock_ec2.stub!(:regions).and_return({'us-east-1': mock_ec2}.stringify_keys)
    mock_subnet = mock(AWS::EC2::Subnet, id: 'subnet-123456')
    mock_subnet.stub!(:vpc).and_return(mock(AWS::EC2::VPC))
    mock_ec2.stub!(:subnets).and_return({'subnet-123456': mock_subnet}.stringify_keys)
    Hailstorm::Support::AwsAdapter::EC2.any_instance.stub(:ec2_resource).and_return(mock_ec2)
    mock_ec2.should_receive(:regions)
    mock_subnet.should_receive(:vpc)
    ec2_adapter = Hailstorm::Support::AwsAdapter::EC2.new(
      access_key_id: 'A',
      secret_key_id: 's',
      region: 'us-east-1',
      vpc_subnet_id: 'subnet-123456'
    )

    expect(ec2_adapter.vpc).to_not be_nil
  end

  it 'should not initialize vpc by default' do
    expect(@aws_adapter.vpc).to be_nil
  end

  context '#systems_ok' do
    context 'EC2 instance checks passed' do
      it 'should return true' do
        @aws_adapter.ec2.stub_chain(:client, :describe_instance_status).and_return(:instance_status_set => [
            system_status: {
                details: [{ name: 'reachability', status: 'passed'}]
            },
            instance_status: {
                details: [{ name: 'reachability', status: 'passed'}]
            }
        ])
        expect(@aws_adapter.send(:systems_ok, mock(AWS::EC2::Instance, id: 'i-123'))).to be_true
      end
    end
  end

  context '#ec2_instance_ready?' do
    context 'instance exists' do
      context 'status is :running' do
        context 'systems_ok == true' do
          it 'should be true' do
            mock_instance = mock(AWS::EC2::Instance, exists?: true, status: :running)
            @aws_adapter.stub!(:systems_ok).and_return(true)
            expect(@aws_adapter.instance_ready?(mock_instance)).to be_true
          end
        end
      end
    end
  end

  context '#first_available_zone' do
    it 'should fetch the first available zone' do
      @aws_adapter.ec2
                  .stub!(:availability_zones)
                  .and_return(
                    [
                      mock(AWS::EC2::AvailabilityZone, state: :unavailable, name: 'us-east-1a'),
                      mock(AWS::EC2::AvailabilityZone, state: :available, name: 'us-east-1b'),
                      mock(AWS::EC2::AvailabilityZone, state: :available, name: 'us-east-1c'),
                    ]
                  )
      expect(@aws_adapter.first_available_zone).to eq('us-east-1b')
    end
  end

  context '#find_key_pair' do
    it 'should fetch the key_pair by name' do
      mock_key_pair = mock(AWS::EC2::KeyPair, private_key: 'A', name: 'mock_key_pair')
      mock_key_pair.stub!(:exists?).and_return(true)
      @aws_adapter.ec2.stub!(:key_pairs).and_return({secure: mock_key_pair}.stringify_keys)
      actual_key_pair = @aws_adapter.find_key_pair(name: 'secure')
      expect(actual_key_pair.private_key).to be == mock_key_pair.private_key
    end
  end

  context '#create_key_pair' do
    it 'should create the key pair' do
      mock_key_pair = mock(AWS::EC2::KeyPair, private_key: 'A', name: 'mock_key_pair')
      @aws_adapter.ec2.stub_chain(:key_pairs, :create).and_return(mock_key_pair)
      expect(@aws_adapter.create_key_pair(name: 'mock_key_pair').private_key).to be == 'A'
    end
  end

  context '#create_security_group' do
    it 'should create the security group' do
      mock_sec_group = mock(AWS::EC2::SecurityGroup, id: 'sg-a1')
      mock_collection = mock(AWS::EC2::SecurityGroupCollection)
      mock_collection.stub!(:create).and_return(mock_sec_group)
      @aws_adapter.ec2.stub!(:security_groups).and_return(mock_collection)
      actual_sec_group = @aws_adapter.create_security_group(
        name: 'dmz',
        description: 'DMZ security group',
        vpc: mock(AWS::EC2::VPC)
      )

      expect(actual_sec_group.id).to be == mock_sec_group.id
    end

    it 'should pass all arguments to the AWS library method' do
      mock_collection = mock(AWS::EC2::SecurityGroupCollection)
      mock_collection.should_receive(:create) do |name, attrs|
        expect(name).to be == 'dmz'
        expect(attrs).to be_kind_of(Hash)
        expect(attrs.keys.sort).to eq(%i[description vpc])
      end

      @aws_adapter.ec2.stub!(:security_groups).and_return(mock_collection)
      @aws_adapter.create_security_group(
        name: 'dmz',
        description: 'DMZ security group',
        vpc: mock(AWS::EC2::VPC)
      )
    end
  end

  context '#find_self_owned_ami' do
    it 'should fetch ami by name' do
      mock_ec2_ami = mock(AWS::EC2::Image, state: :available, name: 'hailstorm/vulcan', id: 'ami-123')
      @aws_adapter.ec2.stub_chain(:images, :with_owner).and_return([ mock_ec2_ami ])
      actual_ami = @aws_adapter.find_self_owned_ami(regexp: Regexp.compile('vulcan'))
      expect(actual_ami.id).to eq(mock_ec2_ami.id)
    end
  end

  context '#register_ami' do
    it 'should request AMI registration' do
      mock_ami = mock(AWS::EC2::Image, state: :available, id: 'ami-123')
      @aws_adapter.ec2.stub_chain(:images, :create).and_return(mock_ami)
      actual_ami = @aws_adapter.register_ami(
        name: 'hailstorm/brave',
        instance_id: 'i-67678',
        description: 'AMI for distributed performance testing with Hailstorm'
      )

      expect(actual_ami.id).to eql(mock_ami.id)
    end
  end

  context '#find_subnet' do
    it 'should find subnet with matching tag' do
      mock_subnet = mock(AWS::EC2::Subnet, state: :available, subnet_id: 'subnet-123')
      @aws_adapter.ec2.stub_chain(:subnets, :with_tag).and_return([mock_subnet])
      actual_subnet = @aws_adapter.find_subnet(name_tag: 'hailstorm')
      expect(actual_subnet.subnet_id).to be == mock_subnet.subnet_id
    end
  end

  context '#modify_vpc_attribute' do
    it 'should modify vpc attribute' do
      mock_ec2_client = mock(AWS::EC2::Client)
      @aws_adapter.ec2.stub!(:client).and_return(mock_ec2_client)
      mock_ec2_client.should_receive(:modify_vpc_attribute) do |args|
        expect(args).to be_a(Hash)
        expect(args.keys.sort).to eq(%i[enable_dns_hostnames vpc_id])
        expect(args[:enable_dns_hostnames][:value]).to be_true
      end

      @aws_adapter.modify_vpc_attribute('vpc-123456', enable_dns_hostnames: { value: true })
    end
  end

  context '#create_vpc' do
    it 'should create the vpc' do
      mock_vpc = mock(AWS::EC2::VPC, id: 'vpc-123456')
      @aws_adapter.ec2.stub_chain(:vpcs, :create).and_return(mock_vpc)
      actual_vpc = @aws_adapter.create_vpc(cidr: '10.0.0.0/16')
      expect(actual_vpc.id).to be == mock_vpc.id
    end
  end

  context '#create_subnet' do
    it 'should create the subnet in the VPC' do
      mock_vpc = mock(AWS::EC2::VPC, id: 'vpc-123456')
      mock_subnet = mock(AWS::EC2::Subnet, subnet_id: 'subnet-123456')
      mock_vpc.stub_chain(:subnets, :create).and_return(mock_subnet)
      actual_subnet = @aws_adapter.create_subnet(vpc: mock_vpc, cidr: '10.0.0.0/16')
      expect(actual_subnet.subnet_id).to be == mock_subnet.subnet_id
    end
  end

  context '#create_internet_gateway' do
    it 'should create a gateway to the internet' do
      mock_collection = mock(AWS::EC2::InternetGatewayCollection)
      mock_collection.should_receive(:create).and_return(mock(AWS::EC2::InternetGateway))
      @aws_adapter.ec2.stub!(:internet_gateways).and_return(mock_collection)
      expect(@aws_adapter.create_internet_gateway).to_not be_nil
    end
  end

  context '#create_route_table' do
    it 'should create a route table' do
      mock_route_table = mock(AWS::EC2::RouteTable, route_table_id: 'route-123')
      @aws_adapter.ec2.stub_chain(:route_tables, :create).and_return(mock_route_table)
      mock_vpc = mock(AWS::EC2::VPC, id: 'vpc-123456')
      actual_route_table = @aws_adapter.create_route_table(vpc: mock_vpc)
      expect(actual_route_table.route_table_id).to be == mock_route_table.route_table_id
    end
  end

  context '#all_instances' do
    it 'should iterate over all instances' do
      instances = [
          {status: :stopped, id: 'id-1'},
          {status: [:running, :terminated].each, id: 'id-2'},
          {status: :terminated, id: 'id-3'},
      ].map do |attrs|
        instance = mock(AWS::EC2::Instance, id: attrs[:id])
        instance.stub!(:status) do
          attrs[:status].is_a?(Enumerator) ? attrs[:status].next : attrs[:status]
        end
        instance
      end

      @aws_adapter.ec2.stub!(:instances).and_return(instances)
      iterator = @aws_adapter.all_instances
      expect(iterator.next.id).to be == instances[0].id
      expect(iterator.next.id).to be == instances[1].id
      expect(iterator.next.id).to be == instances[2].id
    end
  end

  context '#find_self_owned_snapshots' do
    it 'should iterate over all snapshots' do
      snapshots = [
          {status: :pending, id: 'snap-1'},
          {status: :completed, id: 'snap-2'}
      ].map do |attrs|
        mock(AWS::EC2::Snapshot, id: attrs[:id], status: attrs[:status])
      end

      @aws_adapter.ec2.stub_chain(:snapshots, :with_owner).and_return(snapshots)
      iterator = @aws_adapter.find_self_owned_snapshots
      expect(iterator.next.id).to be == snapshots[0].id
      expect(iterator.next.id).to be == snapshots[1].id
    end
  end

  context '#all_key_pairs' do
    it 'should iterate over all key pairs' do
      key_pair = mock(AWS::EC2::KeyPair, name: 's')
      @aws_adapter.ec2.stub!(:key_pairs).and_return([key_pair])
      iterator = @aws_adapter.all_key_pairs
      expect(iterator.next.name).to be == key_pair.name
    end
  end

  context '#all_security_groups' do
    it 'should iterate over all security groups' do
      sec_group = mock(AWS::EC2::SecurityGroup, name: 'hailstorm')
      @aws_adapter.ec2.stub!(:security_groups).and_return([sec_group])
      iterator = @aws_adapter.all_security_groups
      expect(iterator.next.name).to be == sec_group.name
    end
  end

  context '#find_security_group' do
    it 'should find the security group by name' do
      sec_group = mock(AWS::EC2::SecurityGroup, name: 'hailstorm')
      @aws_adapter.ec2.stub_chain(:security_groups, :filter).and_return([sec_group])
      expect(@aws_adapter.find_security_group(name: 'hailstorm').name).to be == sec_group.name
    end
  end

  context '#find_instance' do
    it 'should find an instance by instance_id' do
      mock_instance = mock(AWS::EC2::Instance, instance_id: 'i-123456')
      @aws_adapter.ec2.stub!(:instances).and_return({'i-123456': mock_instance}.stringify_keys)
      expect(@aws_adapter.find_instance(instance_id: 'i-123456').instance_id).to be == mock_instance.instance_id
    end
  end

  context '#create_instance' do
    it 'should create EC2 instance' do
      mock_instance = mock(AWS::EC2::Instance, instance_id: 'i-123456')
      @aws_adapter.ec2.stub_chain(:instances, :create).and_return(mock_instance)
      expect(@aws_adapter.create_instance(ami_id: 'ami-123456').instance_id).to be == mock_instance.instance_id
    end
  end

  context '.eager_autoload!' do
    it 'should autoload AWS' do
      AWS.should_receive(:eager_autoload!)
      Hailstorm::Support::AwsAdapter.eager_autoload!
    end
  end
end
