# frozen_string_literal: true

require 'spec_helper'
require 'ostruct'
require 'yaml'

require 'hailstorm/model/cluster'
require 'hailstorm/model/amazon_cloud'
require 'hailstorm/model/project'
require 'hailstorm/model/master_agent'
require 'hailstorm/model/slave_agent'
require 'hailstorm/model/jmeter_plan'

describe Hailstorm::Model::AmazonCloud do
  AWS_ADAPTER_CLASS = Hailstorm::Support::AwsAdapter

  # @param [Hailstorm::Model::AmazonCloud] aws
  def stub_aws!(aws)
    allow(aws).to receive(:identity_file_exists)
    allow(aws).to receive(:set_availability_zone)
    allow(aws).to receive(:create_agent_ami)
    allow(aws).to receive(:provision_agents)
    allow(aws).to receive(:secure_identity_file)
    allow(aws).to receive(:create_security_group)
    allow(aws).to receive(:assign_vpc_subnet)
  end

  before(:each) do
    @aws = Hailstorm::Model::AmazonCloud.new
  end

  it 'should be valid with project, vpc_subnet_id and the keys' do
    @aws.project = Hailstorm::Model::Project.new(project_code: 'amazon_cloud_spec')
    @aws.access_key = 'foo'
    @aws.secret_key = 'bar'
    expect(@aws).to be_valid
    expect(@aws.region).to eql('us-east-1')
    expect(@aws.slug).to eql('Amazon Cloud, region: us-east-1')
  end

  context 'AWS client factory' do
    it 'should make an EC2 instance client' do
      mock_client = Object.new.extend(Hailstorm::Behavior::AwsAdaptable::InstanceClient)
      client_factory = Hailstorm::Behavior::AwsAdaptable::ClientFactory.new(instance_client: mock_client)
      allow(Hailstorm::Support::AwsAdapter).to receive(:clients).and_return(client_factory)
      expect(@aws.send(:instance_client)).to_not be_nil
      expect(@aws.send(:instance_client)).to be_kind_of(mock_client.class)
    end

    it 'should make an EC2 security group client' do
      mock_client = Object.new.extend(Hailstorm::Behavior::AwsAdaptable::SecurityGroupClient)
      client_factory = Hailstorm::Behavior::AwsAdaptable::ClientFactory.new(security_group_client: mock_client)
      allow(Hailstorm::Support::AwsAdapter).to receive(:clients).and_return(client_factory)
      expect(@aws.send(:security_group_client)).to_not be_nil
      expect(@aws.send(:security_group_client)).to be_kind_of(mock_client.class)
    end

    it 'should make EC2 client' do
      mock_client = Object.new.extend(Hailstorm::Behavior::AwsAdaptable::Ec2Client)
      client_factory = Hailstorm::Behavior::AwsAdaptable::ClientFactory.new(ec2_client: mock_client)
      allow(Hailstorm::Support::AwsAdapter).to receive(:clients).and_return(client_factory)
      expect(@aws.send(:ec2_client)).to_not be_nil
      expect(@aws.send(:ec2_client)).to be_kind_of(mock_client.class)
    end
  end

  context '#default_max_threads_per_agent' do
    it 'should increase with instance class and type' do
      pricing_options = []
      all_results = []
      %i[t2 t3 t3a m4 m5 m5a m5ad m5d m5dn m5n].each do |instance_class|
        iclass_results = []
        [:nano, :micro, :small, :medium, :large, :xlarge, '2xlarge'.to_sym, '4xlarge'.to_sym, '10xlarge'.to_sym,
         '16xlarge'.to_sym].each do |instance_size|
          @aws.instance_type = "#{instance_class}.#{instance_size}"
          default_threads = @aws.send(:default_max_threads_per_agent)
          iclass_results << default_threads
          expect(iclass_results).to eql(iclass_results.sort)
          all_results << default_threads
          pricing_options << "#{instance_class}.#{instance_size}: #{default_threads}"
        end
      end

      expect(all_results).to_not include(nil)
      expect(all_results).to_not include(0)
    end
  end

  context '#ssh_options' do
    before(:each) do
      @aws.ssh_identity = 'blah'
      @aws.project = Hailstorm::Model::Project.new(project_code: 'amazon_cloud_spec')
    end
    context 'standard SSH port' do
      it 'should have :keys' do
        expect(@aws.ssh_options).to include(:keys)
      end
      it 'should not have :port' do
        expect(@aws.ssh_options).to_not include(:port)
      end
    end
    context 'non-standard SSH port' do
      before(:each) do
        @aws.ssh_port = 8022
      end
      it 'should have :keys' do
        expect(@aws.ssh_options).to include(:keys)
      end
      it 'should have :port' do
        expect(@aws.ssh_options).to include(:port)
        expect(@aws.ssh_options[:port]).to eql(8022)
      end
    end
  end

  context 'non-standard SSH ports' do
    before(:each) do
      @aws.project = Hailstorm::Model::Project.new(project_code: 'amazon_cloud_spec')
      @aws.ssh_port = 8022
      @aws.active = true
      allow(@aws).to receive(:identity_file_exists)
    end
    context 'agent_ami is not present' do
      it 'should raise an error' do
        @aws.valid?
        expect(@aws.errors).to include(:agent_ami)
      end
    end
    context 'agent_ami is present' do
      it 'should not raise an error' do
        @aws.agent_ami = 'fubar'
        @aws.valid?
        expect(@aws.errors).to_not include(:agent_ami)
      end
    end
  end

  context '#create_security_group' do
    context 'on save' do
      before(:each) do
        @aws.project = Hailstorm::Model::Project.where(project_code: 'amazon_cloud_spec').first_or_create!
        @aws.access_key = 'dummy'
        @aws.secret_key = 'dummy'
        @aws.vpc_subnet_id = 'subnet-1234'
        stub_aws!(@aws)
        @aws.active = true
      end

      context 'agent_ami is not specfied' do
        it 'should be invoked' do
          expect(@aws).to receive(:create_security_group)
          @aws.save!
        end
      end

      context 'agent_ami is specified' do
        it 'should be invoked' do
          @aws.agent_ami = 'ami-42'
          expect(@aws).to receive(:create_security_group)
          @aws.save!
        end
      end
    end

    it 'should delegate to helper' do
      allow(@aws).to receive(:client_factory).and_return(
        Hailstorm::Behavior::AwsAdaptable::ClientFactory.new(
          subnet_client: instance_double(Hailstorm::Behavior::AwsAdaptable::SubnetClient),
          security_group_client: instance_double(Hailstorm::Behavior::AwsAdaptable::SecurityGroupClient)
        )
      )

      expect_any_instance_of(Hailstorm::Model::Helper::SecurityGroupCreator).to receive(:create_security_group)
      @aws.send(:create_security_group)
    end
  end

  context '#agents_to_remove' do
    it 'should yield agents that are not needed for load generation' do
      allow(@aws).to receive(:agents_to_add).and_return(-1)
      @aws.project = Hailstorm::Model::Project.where(project_code: 'amazon_cloud_spec').first_or_create!
      @aws.access_key = 'dummy'
      @aws.secret_key = 'dummy'
      @aws.region = 'ua-east-1'
      @aws.vpc_subnet_id = 'subnet-1234'
      @aws.save!

      Hailstorm::Model::Cluster.create!(project: @aws.project, cluster_type: @aws.class.name, clusterable_id: @aws.id)
      jmeter_plan = Hailstorm::Model::JmeterPlan.create!(project: @aws.project, test_plan_name: 'A', content_hash: 'A')
      agent = Hailstorm::Model::MasterAgent.create!(clusterable_id: @aws.id, clusterable_type: @aws.class.name,
                                                    jmeter_plan: jmeter_plan)
      agent.update_column(:active, true)

      @aws.send(:agents_to_remove, @aws.load_agents, 1) do |ag|
        expect(ag.id).to be == agent.id
      end
    end
  end

  context '#process_jmeter_plan' do
    context 'project.master_slave_mode? == true' do
      before(:each) do
        @aws.project = Hailstorm::Model::Project.create!(project_code: 'amazon_cloud_spec', master_slave_mode: true)
        @aws.access_key = 'dummy'
        @aws.secret_key = 'dummy'
        @aws.region = 'ua-east-1'
        @aws.vpc_subnet_id = 'subnet-1234'
        @aws.save!

        @required_load_agent_count = 2
        allow(@aws).to receive(:required_load_agent_count).and_return(@required_load_agent_count)
        @jmeter_plan = Hailstorm::Model::JmeterPlan.create!(project: @aws.project, test_plan_name: 'A',
                                                            content_hash: 'A')
      end
      it 'should not have more than one master' do
        2.times do
          Hailstorm::Model::MasterAgent.create!(clusterable_id: @aws.id, clusterable_type: @aws.class.name,
                                                jmeter_plan: @jmeter_plan)
        end
        expect { @aws.send(:process_jmeter_plan, @jmeter_plan) }
          .to raise_error(Hailstorm::MasterSlaveSwitchOnConflict) { |error| expect(error.diagnostics).to_not be_nil }
      end
      it 'should create or enable other slave agents' do
        Hailstorm::Model::MasterAgent.create!(clusterable_id: @aws.id, clusterable_type: @aws.class.name,
                                              jmeter_plan: @jmeter_plan)
        2.times do
          Hailstorm::Model::SlaveAgent.create!(clusterable_id: @aws.id, clusterable_type: @aws.class.name,
                                               jmeter_plan: @jmeter_plan)
        end
        expect(@aws).to receive(:create_or_enable) do |_arg1, _arg2, arg3|
          expect(arg3).to be == :slave_agents
        end
        @aws.send(:process_jmeter_plan, @jmeter_plan)
      end
    end
  end

  context 'on update(active: false)' do
    before(:each) do
      @aws.project = Hailstorm::Model::Project.create!(project_code: 'amazon_cloud_spec')
      @aws.access_key = 'dummy'
      @aws.secret_key = 'dummy'
      @aws.region = 'ua-east-1'
      @aws.vpc_subnet_id = 'subnet-1234'
      @aws.save!

      @jmeter_plan = Hailstorm::Model::JmeterPlan.create!(project: @aws.project, test_plan_name: 'A',
                                                          content_hash: 'A')
    end
    it 'should disable master agents' do
      2.times do
        Hailstorm::Model::MasterAgent.create!(clusterable_id: @aws.id, clusterable_type: @aws.class.name,
                                              jmeter_plan: @jmeter_plan)
      end

      @aws.update_column(:active, true)
      @aws.update_attribute(:active, false)
      @aws.load_agents.each do |ag|
        expect(ag).to_not be_active
      end
    end

    it 'should raise error if 1 or more slave_agents exist' do
      Hailstorm::Model::SlaveAgent.create!(clusterable_id: @aws.id, clusterable_type: @aws.class.name,
                                           jmeter_plan: @jmeter_plan)
      expect { @aws.send(:process_jmeter_plan, @jmeter_plan) }
        .to raise_error(Hailstorm::MasterSlaveSwitchOffConflict) { |error| expect(error.diagnostics).to_not be_nil }
    end
  end

  context '#public_properties' do
    it 'should only have allowed properties' do
      @aws.access_key = 'foo'
      @aws.secret_key = 'bar'
      @aws.region = 'us-west-1'
      props = @aws.public_properties
      expect(props).to include(:region)
      expect(props).to_not include(:secret_key)
    end
  end

  context '#identity_file_exists' do
    it 'should validate or create a key pair' do
      allow(@aws).to receive(:identity_file_path).and_return('/dev/null')
      @aws.ssh_identity = 'secure'
      client_factory = Hailstorm::Behavior::AwsAdaptable::ClientFactory.new(
        key_pair_client: instance_double(Hailstorm::Behavior::AwsAdaptable::KeyPairClient)
      )

      allow(@aws).to receive(:client_factory).and_return(client_factory)
      expect_any_instance_of(Hailstorm::Model::Helper::AwsIdentityHelper).to receive(:validate_or_create_identity)

      @aws.send(:identity_file_exists)
    end
  end

  context '#set_availability_zone' do
    context 'JMeter run in master-slave mode' do
      context 'zone is not assigned' do
        it 'should assign the first available zone' do
          @aws.project = Hailstorm::Model::Project.new(project_code: __FILE__, master_slave_mode: true)
          mock_ec2_client = instance_double(Hailstorm::Behavior::AwsAdaptable::Ec2Client)
          allow(mock_ec2_client).to receive(:first_available_zone).and_return('us-east-1a')
          allow(@aws).to receive(:ec2_client).and_return(mock_ec2_client)
          @aws.send(:set_availability_zone)
          expect(@aws.zone).to be == 'us-east-1a'
        end
      end
    end
  end

  context Hailstorm::Behavior::Provisionable do
    context '#agent_before_save_on_create' do
      it 'should start_agent' do
        expect(@aws).to receive(:start_agent)
        @aws.agent_before_save_on_create(nil)
      end
    end

    context '#agents_to_add' do
      context 'required and current count is same' do
        it 'should return 0' do
          query = instance_double(ActiveRecord::Relation, count: 5)
          expect(@aws.agents_to_add(query, 5) {}).to be_zero
        end
      end
      context 'required count is greater than the current count' do
        it 'should yield and return the differential' do
          query = instance_double(ActiveRecord::Relation, count: 3)
          count = @aws.agents_to_add(query, 5) do |q, c|
            expect(c).to be == 2
            expect(q).to be == query
          end
          expect(count).to be == 2
        end
      end
    end
  end

  context '#create_or_enable' do
    context 'with 1 existing load agent' do
      context 'with 2 load agents needed' do
        it 'should create 1 new load agent' do
          stub_aws!(@aws)
          allow(@aws).to receive(:start_agent)
          @aws.project = Hailstorm::Model::Project.create!(project_code: 'amazon_cloud_spec')
          @aws.access_key = 'foo'
          @aws.secret_key = 'bar'
          @aws.max_threads_per_agent = 25
          @aws.vpc_subnet_id = 'subnet-1234'
          @aws.save!

          jmeter_plan = Hailstorm::Model::JmeterPlan.create!(
            project: @aws.project,
            test_plan_name: 'sample',
            content_hash: 'A',
            active: false
          )

          jmeter_plan.update_column(:active, true)

          allow_any_instance_of(Hailstorm::Model::LoadAgent).to receive(:upload_scripts)
          agent = Hailstorm::Model::MasterAgent.create!(
            clusterable_id: @aws.id,
            clusterable_type: @aws.class.name,
            jmeter_plan: jmeter_plan
          )

          allow(jmeter_plan).to receive(:num_threads).and_return(30)

          @aws.create_or_enable({ jmeter_plan_id: jmeter_plan.id, active: true }, jmeter_plan, :master_agents)

          expect(Hailstorm::Model::MasterAgent.count).to eq(2)
          expect(Hailstorm::Model::MasterAgent.all.map(&:id)).to include(agent.id)
        end
      end
    end
  end

  context '#provision_agents' do
    context 'when reconfiguring with multiple JMeter plans and load agents in a cluster' do
      it 'should start the correct load agents' do
        allow_any_instance_of(Hailstorm::Model::JmeterPlan).to receive(:num_threads).and_return(50)
        allow_any_instance_of(Hailstorm::Model::LoadAgent).to receive(:upload_scripts)
        stub_aws!(@aws)
        allow(@aws).to receive(:provision_agents).and_call_original

        allow(@aws).to receive(:start_agent)
        @aws.project = Hailstorm::Model::Project.create!(project_code: 'amazon_cloud_spec')
        @aws.access_key = 'foo'
        @aws.secret_key = 'bar'
        @aws.vpc_subnet_id = 'subnet-1234'
        @aws.max_threads_per_agent = 50
        @aws.save!

        jmeter_plan1 = Hailstorm::Model::JmeterPlan.create!(
          project: @aws.project,
          test_plan_name: 'sample A',
          content_hash: 'A',
          active: false
        )

        jmeter_plan1.update_column(:active, true)

        jmeter_plan2 = Hailstorm::Model::JmeterPlan.create!(
          project: @aws.project,
          test_plan_name: 'sample B',
          content_hash: 'B',
          active: false
        )

        jmeter_plan2.update_column(:active, true)

        @aws.update_column(:active, true)
        @aws.provision_agents
        expect(Hailstorm::Model::MasterAgent.count).to be == 2

        jmeter_plan2.update_attribute(:active, false)

        @aws.update_column(:active, false)
        @aws.max_threads_per_agent = 25
        @aws.save!

        @aws.update_column(:active, true)
        @aws.provision_agents
        expect(Hailstorm::Model::MasterAgent.count).to be == 3
        expect(Hailstorm::Model::MasterAgent.where(jmeter_plan_id: jmeter_plan2.id).count).to be == 1
        expect(Hailstorm::Model::MasterAgent.where(jmeter_plan_id: jmeter_plan2.id).first).to_not be_active
        expect(Hailstorm::Model::MasterAgent.where(jmeter_plan_id: jmeter_plan1.id, active: true).count).to be == 2
      end
    end
  end

  context '#assign_vpc_subnet' do
    it 'should create a Hailstorm public subnet if it does not exist' do
      mock_client_factory = Hailstorm::Behavior::AwsAdaptable::ClientFactory.new(
        vpc_client: instance_double(Hailstorm::Behavior::AwsAdaptable::VpcClient),
        subnet_client: instance_double(Hailstorm::Behavior::AwsAdaptable::SubnetClient),
        internet_gateway_client: instance_double(Hailstorm::Behavior::AwsAdaptable::InternetGatewayClient),
        route_table_client: instance_double(Hailstorm::Behavior::AwsAdaptable::RouteTableClient)
      )

      allow(@aws).to receive(:client_factory).and_return(mock_client_factory)
      allow_any_instance_of(Hailstorm::Model::Helper::VpcHelper).to receive(
        :find_or_create_vpc_subnet
      ).and_return('subnet-123')
      @aws.send(:assign_vpc_subnet)
      expect(@aws.vpc_subnet_id).to be == 'subnet-123'
    end
  end

  context '#create_agent_ami' do
    it 'should delegate to helper' do
      mock_instance_client = instance_double(Hailstorm::Behavior::AwsAdaptable::InstanceClient)
      allow(@aws).to receive(:instance_client).and_return(mock_instance_client)
      mock_ec2_instance_helper = instance_double(Hailstorm::Model::Helper::Ec2InstanceHelper)
      allow(@aws).to receive(:ec2_instance_helper).and_return(mock_ec2_instance_helper)
      mock_sg_finder = instance_double(Hailstorm::Model::Helper::SecurityGroupFinder)
      allow(@aws).to receive(:security_group_finder).and_return(mock_sg_finder)
      mock_cf = instance_double(Hailstorm::Behavior::AwsAdaptable::AmiClient)
      mock_client_factory = Hailstorm::Behavior::AwsAdaptable::ClientFactory.new(ami_client: mock_cf)

      allow(@aws).to receive(:client_factory).and_return(mock_client_factory)
      expect_any_instance_of(Hailstorm::Model::Helper::AmiHelper).to receive(:create_agent_ami!)
      @aws.send(:create_agent_ami)
    end
  end

  it 'should instantiate security_group_finder' do
    mock_client_factory = Hailstorm::Behavior::AwsAdaptable::ClientFactory.new(
      security_group_client: instance_double(Hailstorm::Behavior::AwsAdaptable::SecurityGroupClient),
      ec2_client: instance_double(Hailstorm::Behavior::AwsAdaptable::Ec2Client)
    )

    allow(@aws).to receive(:client_factory).and_return(mock_client_factory)
    expect { @aws.send(:security_group_finder) }.to_not raise_error
  end

  it 'should instantiate ec2_instance_helper' do
    @aws.project = Hailstorm::Model::Project.create!(project_code: 'amazon_cloud_spec')
    @aws.ssh_identity = 'secure'
    mock_client_factory = Hailstorm::Behavior::AwsAdaptable::ClientFactory.new(
      instance_client: instance_double(Hailstorm::Behavior::AwsAdaptable::InstanceClient)
    )

    allow(@aws).to receive(:client_factory).and_return(mock_client_factory)
    expect { @aws.send(:ec2_instance_helper) }.to_not raise_error
  end

  context '#cleanup' do
    before(:each) do
      @aws.active = true
      @aws.autogenerated_ssh_key = true
      allow(@aws).to receive(:identity_file_path).and_return('secure.pem')
      @aws.ssh_identity = 'secure'
      @mock_key_pair_client = instance_double(Hailstorm::Behavior::AwsAdaptable::KeyPairClient)
      client_factory = Hailstorm::Behavior::AwsAdaptable::ClientFactory.new(key_pair_client: @mock_key_pair_client)
      allow(@aws).to receive(:client_factory).and_return(client_factory)
    end

    context 'key_pair exists' do
      it 'should delete the key_pair' do
        allow(@mock_key_pair_client).to receive(:find).and_return('key-pair-123')
        expect(@mock_key_pair_client).to receive(:delete).with(key_pair_id: 'key-pair-123')
        expect(FileUtils).to receive(:safe_unlink)
        @aws.cleanup
      end
    end

    context 'key_pair does not exist' do
      it 'should do nothing' do
        allow(@mock_key_pair_client).to receive(:find).and_return(nil)
        expect(@mock_key_pair_client).to_not receive(:delete)
        expect(FileUtils).to_not receive(:safe_unlink)
        @aws.cleanup
      end
    end
  end

  context '#purge' do
    it 'should clean the regions with active Amazon Cloud clusters' do
      attrs = { access_key: 'foo-east-1', secret_key: 'bar-east-1', region: 'us-east-1', active: false }
      clusterable = Hailstorm::Model::AmazonCloud.new(attrs)
      clusterable.project = Hailstorm::Model::Project.new(project_code: Digest::SHA2.new.to_s[0..5])
      stub_aws!(clusterable)
      clusterable.save!
      clusterable.update_column(:active, true)

      mock_subnet_client = instance_double(Hailstorm::Behavior::AwsAdaptable::SubnetClient)
      allow(mock_subnet_client).to receive(:find_vpc).and_return('vpc-123')
      allow(clusterable).to receive(:subnet_client).and_return(mock_subnet_client)
      mock_cleaner = instance_double(Hailstorm::Support::AmazonAccountCleaner)
      expect(mock_cleaner).to receive(:cleanup)
      clusterable.purge(mock_cleaner)
      expect(clusterable.agent_ami).to be_nil
    end
  end
end
