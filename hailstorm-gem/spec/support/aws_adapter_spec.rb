require 'spec_helper'
require 'hailstorm/support/aws_adapter'

describe Hailstorm::Support::AwsAdapter do
  before(:each) do
    mock_ec2 = mock(Aws::EC2::Resource)
    @aws_adapter = Hailstorm::Support::AwsAdapter::EC2.new({}, ec2: mock_ec2)
  end

  it 'should initialize the EC2 adapter' do
    mock_subnet = mock(Aws::EC2::Subnet, id: 'subnet-123456')
    mock_subnet.stub!(:vpc).and_return(mock(Aws::EC2::Vpc))
    Aws::EC2::Resource.any_instance.stub(:subnet).and_return(mock_subnet)
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
        @aws_adapter.ec2.stub_chain(:client, :describe_instance_status, :to_h).and_return(
          :instance_statuses => [
            system_status: {
              details: [{ name: 'reachability', status: 'passed'}]
            },
            instance_status: {
              details: [{ name: 'reachability', status: 'passed'}]
            }
          ]
        )

        @aws_adapter.ec2.client.should_receive(:describe_instance_status).with({instance_ids: %W[i-123]})
        expect(@aws_adapter.send(:systems_ok, mock(Aws::EC2::Instance, id: 'i-123'))).to be_true
      end
    end
  end

  context '#ec2_instance_ready?' do
    context 'instance exists' do
      context 'status is :running' do
        context 'systems_ok == true' do
          it 'should be true' do
            mock_instance = mock(Aws::EC2::Instance, exists?: true)
            mock_instance.stub_chain(:state, :name).and_return(:running)
            @aws_adapter.stub!(:systems_ok).and_return(true)
            expect(@aws_adapter.instance_ready?(described_class::EC2::Instance.new(mock_instance))).to be_true
          end
        end
      end
    end
  end

  context '#first_available_zone' do
    it 'should fetch the first available zone' do
      @aws_adapter.ec2
                  .stub_chain(:client, :describe_availability_zones, :to_h)
                  .and_return(
                    {
                       availability_zones: [
                         { state: 'unavailable', zone_name: 'us-east-1a', region_name: 'us-east-1' },
                         { state: 'available', zone_name: 'us-east-1b', region_name: 'us-east-1' },
                         { state: 'available', zone_name: 'us-east-1c', region_name: 'us-east-1' },
                       ]
                    }
                  )
      expect(@aws_adapter.first_available_zone).to eq('us-east-1b')
    end
  end

  context '#find_key_pair' do
    it 'should fetch the key_pair by name' do
      mock_key_pair = mock(Aws::EC2::KeyPair, key_material: 'A', key_name: 'mock_key_pair')
      @aws_adapter.ec2.stub!(:key_pair).and_return(mock_key_pair)
      actual_key_pair = @aws_adapter.find_key_pair(name: 'mock_key_pair')
      expect(actual_key_pair.key_material).to be == mock_key_pair.key_material
    end
  end

  context '#create_key_pair' do
    it 'should create the key pair' do
      mock_key_pair = mock(Aws::EC2::KeyPair, key_material: 'A', key_name: 'mock_key_pair')
      @aws_adapter.ec2.stub!(:create_key_pair).and_return(mock_key_pair)
      expect(@aws_adapter.create_key_pair(name: 'mock_key_pair').key_material).to be == 'A'
    end
  end

  context '#create_security_group' do
    it 'should create the security group in VPC' do
      mock_sec_group = mock(Aws::EC2::SecurityGroup, id: 'sg-a1')
      @aws_adapter.ec2.stub!(:create_security_group).and_return(mock_sec_group)
      actual_sec_group = @aws_adapter.create_security_group(
        name: 'dmz',
        description: 'DMZ security group',
        vpc: mock(Aws::EC2::Vpc, vpc_id: 'vpc-123')
      )

      expect(actual_sec_group.id).to be == mock_sec_group.id
    end

    it 'should pass all arguments to the AWS library method' do
      security_group_attrs = {
        name: 'dmz',
        description: 'DMZ security group',
        vpc: mock(Aws::EC2::Vpc, vpc_id: 'vpc-123')
      }

      @aws_adapter.ec2.should_receive(:create_security_group).with(
        description: security_group_attrs[:description],
        group_name: security_group_attrs[:name],
        vpc_id: 'vpc-123'
      )

      @aws_adapter.create_security_group(security_group_attrs)
    end

    it 'should create security group in ec2' do
      security_group_attrs = { name: 'dmz', description: 'DMZ security group' }
      @aws_adapter.ec2.should_receive(:create_security_group).with(
        description: security_group_attrs[:description],
        group_name: security_group_attrs[:name]
      )

      @aws_adapter.create_security_group(security_group_attrs)
    end
  end

  context '#find_self_owned_ami' do
    it 'should fetch ami by name' do
      mock_ec2_ami = mock(Aws::EC2::Image, state: :available, name: 'hailstorm/vulcan', id: 'ami-123')
      @aws_adapter.ec2.should_receive(:images).with(owners: %W[self]).and_return([ mock_ec2_ami ])
      actual_ami = @aws_adapter.find_self_owned_ami(regexp: Regexp.compile('vulcan'))
      expect(actual_ami.id).to eq(mock_ec2_ami.id)
    end
  end

  context '#register_ami' do
    it 'should request AMI registration' do
      mock_ami = mock(Aws::EC2::Image, state: :available, id: 'ami-123')
      @aws_adapter.ec2.stub!(:register_image).and_return(mock_ami)
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
      mock_subnet = mock(Aws::EC2::Subnet, state: :available, subnet_id: 'subnet-123')
      @aws_adapter.ec2
        .should_receive(:subnets)
        .with(filters: [{name: "tag:Name", values: ['hailstorm']}])
        .and_return([mock_subnet])
      actual_subnet = @aws_adapter.find_subnet(name_tag: 'hailstorm')
      expect(actual_subnet.subnet_id).to be == mock_subnet.subnet_id
    end
  end

  context '#modify_vpc_attribute' do
    it 'should modify vpc attribute' do
      mock_ec2_client = mock(Aws::EC2::Client)
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
      mock_vpc = mock(Aws::EC2::Vpc, id: 'vpc-123456')
      @aws_adapter.ec2.should_receive(:create_vpc).with(cidr_block: '10.0.0.0/16').and_return(mock_vpc)
      actual_vpc = @aws_adapter.create_vpc(cidr: '10.0.0.0/16')
      expect(actual_vpc.id).to be == mock_vpc.id
    end
  end

  context '#create_subnet' do
    it 'should create the subnet in the VPC' do
      mock_vpc = mock(Aws::EC2::Vpc, id: 'vpc-123456')
      mock_subnet = mock(Aws::EC2::Subnet, subnet_id: 'subnet-123456')
      mock_vpc.should_receive(:create_subnet).with(cidr_block: '10.0.0.0/16').and_return(mock_subnet)
      actual_subnet = @aws_adapter.create_subnet(vpc: mock_vpc, cidr: '10.0.0.0/16')
      expect(actual_subnet.subnet_id).to be == mock_subnet.subnet_id
    end
  end

  context '#modify_subnet_attribute' do
    it 'should modify subnet attributes' do
      mock_subnet = mock(Aws::EC2::Subnet, subnet_id: 'subnet-123456')
      mock_client = mock(Aws::EC2::Client)
      @aws_adapter.ec2.stub!(:client).and_return(mock_client)
      mock_client
        .should_receive(:modify_subnet_attribute)
        .with(
          subnet_id: mock_subnet.subnet_id,
          assign_ipv_6_address_on_creation: {value: true},
          map_public_ip_on_launch: {value: true},
          map_customer_owned_ip_on_launch: {value: false}
        )

      subnet = Hailstorm::Support::AwsAdapter::EC2::Subnet.new(mock_subnet)
      @aws_adapter.modify_subnet_attribute(subnet,
                                           assign_ipv_6_address_on_creation: true,
                                           map_public_ip_on_launch: true,
                                           map_customer_owned_ip_on_launch: false)
    end
  end

  context '#create_internet_gateway' do
    it 'should create a gateway to the internet' do
      @aws_adapter.ec2.stub!(:create_internet_gateway).and_return(mock(Aws::EC2::InternetGateway))
      expect(@aws_adapter.create_internet_gateway).to_not be_nil
    end
  end

  context '#create_route_table' do
    it 'should create a route table' do
      mock_vpc = mock(Aws::EC2::Vpc, id: 'vpc-123456')
      mock_route_table = mock(Aws::EC2::RouteTable, route_table_id: 'route-123')
      @aws_adapter.ec2.should_receive(:create_route_table).with(vpc_id: mock_vpc.id).and_return(mock_route_table)
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
        instance = mock(Aws::EC2::Instance, id: attrs[:id])
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
        mock(Aws::EC2::Snapshot, id: attrs[:id], status: attrs[:status])
      end

      @aws_adapter.ec2.should_receive(:snapshots).with(owner_ids: %w[self]).and_return(snapshots)
      iterator = @aws_adapter.find_self_owned_snapshots
      expect(iterator.next.id).to be == snapshots[0].id
      expect(iterator.next.id).to be == snapshots[1].id
    end
  end

  context '#all_key_pairs' do
    it 'should iterate over all key pairs' do
      key_pair = mock(Aws::EC2::KeyPairInfo, name: 's')
      @aws_adapter.ec2.stub!(:key_pairs).and_return([key_pair])
      iterator = @aws_adapter.all_key_pairs
      expect(iterator.next.name).to be == key_pair.name
    end
  end

  context '#all_security_groups' do
    it 'should iterate over all security groups' do
      sec_group = mock(Aws::EC2::SecurityGroup, group_name: 'hailstorm')
      @aws_adapter.ec2.stub!(:security_groups).and_return([sec_group])
      iterator = @aws_adapter.all_security_groups
      expect(iterator.next.name).to be == sec_group.group_name
    end
  end

  context '#find_security_group' do
    it 'should find the security group by name' do
      sec_group = mock(Aws::EC2::SecurityGroup, group_name: 'hailstorm')
      @aws_adapter
        .ec2
        .should_receive(:security_groups)
        .with(filters: [{name: 'group-name', values: ['hailstorm']}])
        .and_return([sec_group])
      expect(@aws_adapter.find_security_group(name: 'hailstorm').name).to be == sec_group.group_name
    end
  end

  context '#find_instance' do
    it 'should find an instance by instance_id' do
      mock_instance = mock(Aws::EC2::Instance, instance_id: 'i-123456')
      @aws_adapter
        .ec2
        .should_receive(:instances)
        .with(instance_ids: %w[i-123456], max_results: 1)
        .and_return([mock_instance])

      expect(@aws_adapter.find_instance(instance_id: 'i-123456').instance_id).to be == mock_instance.instance_id
    end
  end

  context '#create_instance' do
    it 'should create EC2 instance' do
      mock_instance = mock(Aws::EC2::Instance, instance_id: 'i-123456')
      @aws_adapter
        .ec2
        .should_receive(:create_instances)
        .with(
          image_id: 'ami-1',
          key_name: 's',
          security_group_ids: %w[sg-1],
          instance_type: 't3.small',
          placement: {availability_zone: 'us-east-1a'},
          network_interfaces: [{associate_public_ip_address: true}],
          min_count: 1,
          max_count: 1
        )
        .and_return([mock_instance])

      expect(@aws_adapter
               .create_instance(image_id: 'ami-1',
                                key_name: 's',
                                security_group_ids: %w[sg-1],
                                instance_type: 't3.small',
                                availability_zone: 'us-east-1a',
                                associate_public_ip_address: true).instance_id).to be == mock_instance.instance_id
    end
  end

  context '.eager_autoload!' do
    it 'should autoload AWS' do
      Aws.should_receive(:eager_autoload!)
      Hailstorm::Support::AwsAdapter.eager_autoload!
    end
  end

  context Hailstorm::Support::AwsAdapter::EC2::VPC do
    context '#tag' do
      it 'should create a tag' do
        mock_vpc = mock(Aws::EC2::Vpc)
        mock_vpc.should_receive(:create_tags).with(tags: [{key: 'Name', value: 'hailstorm'}])
        vpc = Hailstorm::Support::AwsAdapter::EC2::VPC.new(mock_vpc)
        vpc.tag('Name', value: 'hailstorm')
      end
    end
  end

  context Hailstorm::Support::AwsAdapter::EC2::Subnet do
    context '#tag' do
      it 'should create a tag' do
        mock_subnet = mock(Aws::EC2::Subnet)
        mock_subnet.should_receive(:create_tags).with(tags: [{key: 'Name', value: 'hailstorm'}])
        subnet = Hailstorm::Support::AwsAdapter::EC2::Subnet.new(mock_subnet)
        subnet.tag('Name', value: 'hailstorm')
      end
    end
  end

  context Hailstorm::Support::AwsAdapter::EC2::InternetGateway do
    context '#tag' do
      it 'should create a tag' do
        mock_igw = mock(Aws::EC2::InternetGateway)
        mock_igw.should_receive(:create_tags).with(tags: [{key: 'Name', value: 'hailstorm'}])
        igw = Hailstorm::Support::AwsAdapter::EC2::InternetGateway.new(mock_igw)
        igw.tag('Name', value: 'hailstorm')
      end
    end

    context '#attach' do
      it 'should attach to a VPC' do
        mock_igw = mock(Aws::EC2::InternetGateway)
        mock_igw.should_receive(:attach_to_vpc).with(vpc_id: 'vpc-123')
        igw = Hailstorm::Support::AwsAdapter::EC2::InternetGateway.new(mock_igw)
        igw.attach(mock(Hailstorm::Support::AwsAdapter::EC2::VPC, vpc_id: 'vpc-123'))
      end
    end

    context Hailstorm::Support::AwsAdapter::EC2::RouteTable do
      context '#create_route' do
        it 'should create a route' do
          mock_route_table = mock(Aws::EC2::RouteTable)
          mock_route_table
            .should_receive(:create_route)
            .with(destination_cidr_block: '0.0.0.0/0', gateway_id: 'igw-123')

          route_table = Hailstorm::Support::AwsAdapter::EC2::RouteTable.new(mock_route_table)
          route_table.create_route(
            '0.0.0.0/0',
            internet_gateway: mock(Hailstorm::Support::AwsAdapter::EC2::InternetGateway, internet_gateway_id: 'igw-123')
          )
        end
      end
    end

    context Hailstorm::Support::AwsAdapter::EC2::Snapshot do
      context '#status' do
        it 'should fetch current state' do
          mock_snapshot = mock(Aws::EC2::Snapshot, snapshot_id: 'snap-123456')
          mock_snapshot.should_receive(:state).and_return('completed')
          snapshot = Hailstorm::Support::AwsAdapter::EC2::Snapshot.new(mock_snapshot)
          expect(snapshot.status).to be == :completed
        end
      end
    end

    context Hailstorm::Support::AwsAdapter::EC2::KeyPair do
      it 'should have private_key attribute' do
        mock_key_pair = mock(Aws::EC2::KeyPair)
        mock_key_pair.should_receive(:key_material).and_return('A')
        key_pair = Hailstorm::Support::AwsAdapter::EC2::KeyPair.new(mock_key_pair)
        expect(key_pair.private_key).to be == 'A'
      end
    end
  end
end
