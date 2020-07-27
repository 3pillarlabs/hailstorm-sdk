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
    aws.stub(:identity_file_exists, nil)
    aws.stub(:set_availability_zone, nil)
    aws.stub(:create_agent_ami, nil)
    aws.stub(:provision_agents, nil)
    aws.stub(:secure_identity_file, nil)
    aws.stub(:create_security_group, nil)
    aws.stub(:assign_vpc_subnet, nil)
  end

  def stub_find_instance(instance_client, load_agent, status = nil, public_ip_address = nil, private_ip_address = nil)
    attrs = {
      instance_id: load_agent.identifier,
      public_ip_address: public_ip_address || '120.34.35.58',
      private_ip_address: private_ip_address || '10.34.10.20',
    }

    attrs.merge!(state: Hailstorm::Behavior::AwsAdaptable::InstanceState.new(name: status.to_s)) if status
    instance = Hailstorm::Behavior::AwsAdaptable::Instance.new(attrs)
    instance.stub!("#{status}?".to_sym).and_return(true) if status
    instance_client.stub!(:find).and_return(instance)
    instance
  end

  before(:each) do
    @aws = Hailstorm::Model::AmazonCloud.new
  end

  it 'maintains a mapping of AMI IDs for AWS regions' do
    @aws.send(:region_base_ami_map).should_not be_empty
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
      Hailstorm::Support::AwsAdapter
        .stub!(:clients)
        .and_return(Hailstorm::Behavior::AwsAdaptable::ClientFactory.new(instance_client: mock_client))

      expect(@aws.send(:instance_client)).to_not be_nil
      expect(@aws.send(:instance_client)).to be_kind_of(mock_client.class)
    end

    it 'should make an EC2 security group client' do
      mock_client = Object.new.extend(Hailstorm::Behavior::AwsAdaptable::SecurityGroupClient)
      Hailstorm::Support::AwsAdapter
        .stub!(:clients)
        .and_return(Hailstorm::Behavior::AwsAdaptable::ClientFactory.new(security_group_client: mock_client))

      expect(@aws.send(:security_group_client)).to_not be_nil
      expect(@aws.send(:security_group_client)).to be_kind_of(mock_client.class)
    end

    it 'should make an EC2 key pair client' do
      mock_client = Object.new.extend(Hailstorm::Behavior::AwsAdaptable::KeyPairClient)
      Hailstorm::Support::AwsAdapter
        .stub!(:clients)
        .and_return(Hailstorm::Behavior::AwsAdaptable::ClientFactory.new(key_pair_client: mock_client))

      expect(@aws.send(:key_pair_client)).to_not be_nil
      expect(@aws.send(:key_pair_client)).to be_kind_of(mock_client.class)
    end

    it 'should make EC2 client' do
      mock_client = Object.new.extend(Hailstorm::Behavior::AwsAdaptable::Ec2Client)
      Hailstorm::Support::AwsAdapter
        .stub!(:clients)
        .and_return(Hailstorm::Behavior::AwsAdaptable::ClientFactory.new(ec2_client: mock_client))

      expect(@aws.send(:ec2_client)).to_not be_nil
      expect(@aws.send(:ec2_client)).to be_kind_of(mock_client.class)
    end

    it 'should make AMI client' do
      mock_client = Object.new.extend(Hailstorm::Behavior::AwsAdaptable::AmiClient)
      Hailstorm::Support::AwsAdapter
        .stub!(:clients)
        .and_return(Hailstorm::Behavior::AwsAdaptable::ClientFactory.new(ami_client: mock_client))

      expect(@aws.send(:ami_client)).to_not be_nil
      expect(@aws.send(:ami_client)).to be_kind_of(mock_client.class)
    end

    it 'should make Subnet client' do
      mock_client = Object.new.extend(Hailstorm::Behavior::AwsAdaptable::SubnetClient)
      Hailstorm::Support::AwsAdapter
        .stub!(:clients)
        .and_return(Hailstorm::Behavior::AwsAdaptable::ClientFactory.new(subnet_client: mock_client))

      expect(@aws.send(:subnet_client)).to_not be_nil
      expect(@aws.send(:subnet_client)).to be_kind_of(mock_client.class)
    end

    it 'should make VPC client' do
      mock_client = Object.new.extend(Hailstorm::Behavior::AwsAdaptable::VpcClient)
      Hailstorm::Support::AwsAdapter
        .stub!(:clients)
        .and_return(Hailstorm::Behavior::AwsAdaptable::ClientFactory.new(vpc_client: mock_client))

      expect(@aws.send(:vpc_client)).to_not be_nil
      expect(@aws.send(:vpc_client)).to be_kind_of(mock_client.class)
    end

    it 'should make Internet Gateway client' do
      mock_client = Object.new.extend(Hailstorm::Behavior::AwsAdaptable::InternetGatewayClient)
      Hailstorm::Support::AwsAdapter
        .stub!(:clients)
        .and_return(Hailstorm::Behavior::AwsAdaptable::ClientFactory.new(internet_gateway_client: mock_client))

      expect(@aws.send(:internet_gateway_client)).to_not be_nil
      expect(@aws.send(:internet_gateway_client)).to be_kind_of(mock_client.class)
    end

    it 'should make Route Table client' do
      mock_client = Object.new.extend(Hailstorm::Behavior::AwsAdaptable::RouteTableClient)
      Hailstorm::Support::AwsAdapter
        .stub!(:clients)
        .and_return(Hailstorm::Behavior::AwsAdaptable::ClientFactory.new(route_table_client: mock_client))

      expect(@aws.send(:route_table_client)).to_not be_nil
      expect(@aws.send(:route_table_client)).to be_kind_of(mock_client.class)
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

  context '.round_off_max_threads_per_agent' do

    it 'should round off to the nearest 5 if <= 10' do
      expect(Hailstorm::Model::AmazonCloud.round_off_max_threads_per_agent(4)).to eq(5)
      expect(Hailstorm::Model::AmazonCloud.round_off_max_threads_per_agent(5)).to eq(5)
      expect(Hailstorm::Model::AmazonCloud.round_off_max_threads_per_agent(8)).to eq(10)
    end

    it 'should round off to the nearest 10 if <= 50' do
      expect(Hailstorm::Model::AmazonCloud.round_off_max_threads_per_agent(11)).to eq(10)
      expect(Hailstorm::Model::AmazonCloud.round_off_max_threads_per_agent(15)).to eq(20)
      expect(Hailstorm::Model::AmazonCloud.round_off_max_threads_per_agent(44)).to eq(40)
      expect(Hailstorm::Model::AmazonCloud.round_off_max_threads_per_agent(45)).to eq(50)
    end

    it 'should round off to the nearest 50 if > 50' do
      expect(Hailstorm::Model::AmazonCloud.round_off_max_threads_per_agent(51)).to eq(50)
      expect(Hailstorm::Model::AmazonCloud.round_off_max_threads_per_agent(75)).to eq(100)
      expect(Hailstorm::Model::AmazonCloud.round_off_max_threads_per_agent(155)).to eq(150)
      expect(Hailstorm::Model::AmazonCloud.round_off_max_threads_per_agent(375)).to eq(400)
    end
  end

  context '#ami_id' do
    before(:each) do
      require 'hailstorm/model/project'
      require 'digest/sha2'
      @aws.project = Hailstorm::Model::Project.new(project_code: Digest::SHA2.new.to_s[0..5])
    end
    context 'with custom JMeter installer' do
      it 'should have project_code appended to custom version' do
        request_name = 'rhapsody-jmeter-3.2_zzz'
        request_path = "#{request_name}.tgz"
        @aws.project.custom_jmeter_installer_url = "http://whodunit.org/a/b/c/#{request_path}"
        @aws.project.send(:set_defaults)
        expect(@aws.send(:ami_id)).to match(Regexp.new(@aws.project.project_code))
      end
    end
    context 'with default JMeter' do
      it 'should only have default jmeter version' do
        @aws.project.send(:set_defaults)
        expect(@aws.send(:ami_id)).to_not match(Regexp.new(@aws.project.project_code))
        expect(@aws.send(:ami_id)).to match(Regexp.new(@aws.project.jmeter_version.to_s))
      end
    end
  end

  context '#setup' do
    context '#active=true' do
      it 'should be persisted' do
        aws = Hailstorm::Model::AmazonCloud.new
        aws.project = Hailstorm::Model::Project.where(project_code: 'amazon_cloud_spec').first_or_create!
        aws.access_key = 'dummy'
        aws.secret_key = 'dummy'
        aws.region = 'ua-east-1'

        stub_aws!(aws)
        aws.should_receive(:identity_file_exists)
        aws.should_receive(:set_availability_zone)
        aws.should_receive(:create_agent_ami)
        aws.should_receive(:provision_agents)
        aws.should_receive(:assign_vpc_subnet) { aws.vpc_subnet_id = 'subnet-1234' }

        aws.active = true
        aws.setup
        expect(aws).to be_persisted
      end

      context 'vpc_subnet_id is present' do
        it 'should not create new subnet' do
          aws = Hailstorm::Model::AmazonCloud.new
          aws.project = Hailstorm::Model::Project.where(project_code: 'amazon_cloud_spec').first_or_create!
          aws.access_key = 'dummy'
          aws.secret_key = 'dummy'
          aws.region = 'ua-east-1'
          aws.vpc_subnet_id = 'subnet-1234'

          stub_aws!(aws)
          aws.should_receive(:identity_file_exists)
          aws.should_receive(:set_availability_zone)
          aws.should_receive(:create_agent_ami)
          aws.should_receive(:provision_agents)
          aws.should_not_receive(:assign_vpc_subnet)

          aws.active = true
          aws.setup
        end
      end
    end
    context '#active=false' do
      it 'should be persisted' do
        aws = Hailstorm::Model::AmazonCloud.new
        aws.project = Hailstorm::Model::Project.where(project_code: 'amazon_cloud_spec_96137').first_or_create!
        aws.access_key = 'dummy'
        aws.secret_key = 'dummy'
        aws.region = 'ua-east-1'

        stub_aws!(aws)
        aws.should_not_receive(:identity_file_exists)
        aws.should_not_receive(:set_availability_zone)
        aws.should_not_receive(:create_agent_ami)
        aws.should_not_receive(:provision_agents)
        aws.should_not_receive(:secure_identity_file)
        aws.should_not_receive(:assign_vpc_subnet)

        aws.active = false
        aws.setup
        expect(aws).to be_persisted
      end
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
      @aws.stub(:identity_file_exists, nil) { true }
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
          @aws.should_receive(:create_security_group)
          @aws.save!
        end
      end

      context 'agent_ami is specified' do
        it 'should be invoked' do
          @aws.agent_ami = 'ami-42'
          @aws.should_receive(:create_security_group)
          @aws.save!
        end
      end
    end

    context 'security group does not exist' do
      it 'should create EC2 security group' do
        mock_sg_client = mock(Hailstorm::Behavior::AwsAdaptable::SecurityGroupClient)
        @aws.stub!(:security_group_client).and_return(mock_sg_client)
        mock_sg_client.stub!(:find).and_return(nil)
        mock_sec_group = Hailstorm::Behavior::AwsAdaptable::SecurityGroup.new(group_id: 'sg-a1')
        mock_sg_client.stub!(:create).and_return(mock_sec_group)
        mock_sg_client.should_receive(:authorize_ingress).exactly(3).times
        mock_sg_client.should_receive(:allow_ping)
        mock_ec2_client = mock(Hailstorm::Behavior::AwsAdaptable::Ec2Client)
        mock_ec2_client.stub!(:find_vpc).and_return('vpc-123')
        @aws.send(:create_security_group)
      end
    end
  end

  context '#create_ec2_instance' do
    before(:each) do
      @aws.stub!(:ssh_options).and_return({})
      @mock_instance = Hailstorm::Behavior::AwsAdaptable::Instance.new(
        instance_id: 'A',
        state: Hailstorm::Behavior::AwsAdaptable::InstanceState.new(name: 'pending'),
        public_ip_address: nil,
        private_ip_address: nil
      )

      mock_instance_client = mock(Hailstorm::Behavior::AwsAdaptable::InstanceClient, create: @mock_instance)
      mock_instance_client.stub!(:find).and_return(@mock_instance)
      mock_instance_client.stub!(:ready?).and_return(true)
      @aws.stub!(:instance_client).and_return(mock_instance_client)
    end

    context 'when ec2 instance is ready' do
      it 'should return clean_instance' do
        @aws.stub!(:ensure_ssh_connectivity).and_return(true)
        instance = @aws.send(:create_ec2_instance, {})
        expect(instance).to eql(@mock_instance)
      end

      it 'should raise error if ssh connectivity fails' do
        Hailstorm::Support::SSH.stub!(:ensure_connection).and_return(false)
        expect { @aws.send(:create_ec2_instance, {}) }.to raise_error(Hailstorm::Exception)
      end
    end

    context 'instance creation failed' do
      it 'should raise error' do
        @aws.send(:instance_client).stub!(:ready?).and_return(false)
        @aws.stub!(:wait_for).and_raise(Hailstorm::Exception, 'mock error')
        expect { @aws.send(:create_ec2_instance, {}) }.to raise_error(Hailstorm::Exception)
      end
    end
  end

  context '#ami_creation_needed?' do
    context '#active == false' do
      it 'should return false' do
        @aws.active = false
        expect(@aws.send(:ami_creation_needed?)).to be_false
      end
    end
    context 'self.agent_ami is nil' do
      it 'should check_for_existing_ami' do
        @aws.active = true
        @aws.agent_ami = nil
        @aws.stub!(check_for_existing_ami: nil)
        @aws.should_receive(:check_for_existing_ami)
        @aws.send(:ami_creation_needed?)
      end
    end
    context 'check_for_existing_ami is not nil' do
      it 'should return false' do
        @aws.active = true
        @aws.agent_ami = nil
        @aws.stub!(:check_for_existing_ami).and_return('ami-1234')
        expect(@aws.send(:ami_creation_needed?)).to be_false
      end
    end
    context 'check_for_existing_ami is nil' do
      it 'should return true' do
        @aws.active = true
        @aws.agent_ami = nil
        @aws.stub!(:check_for_existing_ami).and_return(nil)
        expect(@aws.send(:ami_creation_needed?)).to be_true
      end
    end
  end

  context '#agents_to_remove' do
    it 'should yield agents that are not needed for load generation' do
      @aws.stub!(:agents_to_add).and_return(-1)
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
        @aws.stub!(:required_load_agent_count).and_return(@required_load_agent_count)
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
        @aws.should_receive(:create_or_enable) do |_arg1, _arg2, arg3|
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

  context '#start_agent' do
    before(:each) do
      @mock_instance_client = mock(Hailstorm::Behavior::AwsAdaptable::InstanceClient)
      @aws.stub!(:instance_client).and_return(@mock_instance_client)
    end

    context 'agent is not running' do
      context 'agent exists' do
        it 'should restart the agent' do
          load_agent = Hailstorm::Model::MasterAgent.new(identifier: 'i-w23457889113')
          stub_find_instance(@mock_instance_client, load_agent, :stopped)
          @mock_instance_client.stub!(:running?).and_return(true)
          @mock_instance_client.should_receive(:start)
          @aws.start_agent(load_agent)
        end
      end

      context 'agent does not exist' do
        it 'should create the agent' do
          @aws.project = Hailstorm::Model::Project.where(project_code: 'amazon_cloud_spec').first_or_create!
          load_agent = Hailstorm::Model::MasterAgent.new
          load_agent.id = 1
          instance = stub_find_instance(@mock_instance_client, load_agent)
          @mock_instance_client.should_receive(:tag_name)
          @aws.stub!(:create_agent).and_return(instance)
          @aws.start_agent(load_agent)
          expect(load_agent.identifier).to be == instance.instance_id
          expect(load_agent.public_ip_address).to be == instance.public_ip_address
          expect(load_agent.private_ip_address).to be == instance.private_ip_address
        end
      end
    end
  end

  context '#stop_agent' do
    before(:each) do
      @mock_instance_client = mock(Hailstorm::Behavior::AwsAdaptable::InstanceClient)
      @aws.stub!(:instance_client).and_return(@mock_instance_client)
    end

    context 'without load_agent#identifier' do
      it 'does nothing' do
        @aws.should_not_receive(:wait_for)
        @aws.stop_agent(Hailstorm::Model::MasterAgent.new)
      end
    end
    context 'with load_agent#identifier' do
      it 'should stop the load_agent#instance' do
        load_agent = Hailstorm::Model::MasterAgent.new(identifier: 'i-w23457889113')
        stub_find_instance(@mock_instance_client, load_agent, :running)
        @mock_instance_client.should_receive(:stop)
        @mock_instance_client.stub!(:stopped?).and_return(true)
        @aws.stop_agent(load_agent)
      end
    end
  end

  context '#after_stop_load_generation' do
    context 'with {:suspend => true}' do
      it 'should stop the agent' do
        load_agent = Hailstorm::Model::MasterAgent.new(identifier: 'i-w23457889113',
                                                       public_ip_address: '10.1.23.45',
                                                       active: true)
        @aws.stub_chain(:load_agents, :where) { [load_agent] }
        @aws.should_receive(:stop_agent)
        load_agent.should_receive(:save!)
        @aws.after_stop_load_generation(suspend: true)
        expect(load_agent.public_ip_address).to be_nil
      end
    end
  end

  context '#before_destroy_load_agent' do
    before(:each) do
      @mock_instance_client = mock(Hailstorm::Behavior::AwsAdaptable::InstanceClient)
      @aws.stub!(:instance_client).and_return(@mock_instance_client)
      @load_agent = Hailstorm::Model::MasterAgent.new(identifier: 'i-w23457889113')
    end

    context 'ec2 instance exists' do
      it 'should terminate the ec2 instance' do
        stub_find_instance(@mock_instance_client, @load_agent, :terminated)
        @mock_instance_client.stub!(:terminated?).and_return(true)
        @mock_instance_client.should_receive(:terminate)
        @aws.before_destroy_load_agent(@load_agent)
      end
    end

    context 'ec2 instance does not exist' do
      it 'should do nothing' do
        @mock_instance_client.stub!(:find).and_return(nil)
        @mock_instance_client.should_not_receive(:terminate)
        @aws.before_destroy_load_agent(@load_agent)
      end
    end
  end

  context '#cleanup' do
    before(:each) do
      @aws.active = true
      @aws.autogenerated_ssh_key = true
      @aws.stub!(:identity_file_path).and_return('secure.pem')
      @aws.ssh_identity = 'secure'
      @mock_key_pair_client = mock(Hailstorm::Behavior::AwsAdaptable::KeyPairClient)
      @aws.stub!(:key_pair_client).and_return(@mock_key_pair_client)
    end

    context 'key_pair exists' do
      it 'should delete the key_pair' do
        @mock_key_pair_client.stub!(:find).and_return('key-pair-123')
        @mock_key_pair_client.should_receive(:delete).with(key_pair_id: 'key-pair-123')
        FileUtils.should_receive(:safe_unlink)
        @aws.cleanup
      end
    end

    context 'key_pair does not exist' do
      it 'should do nothing' do
        @mock_key_pair_client.stub!(:find).and_return(nil)
        @mock_key_pair_client.should_not_receive(:delete)
        FileUtils.should_not_receive(:safe_unlink)
        @aws.cleanup
      end
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

  context '#required_load_agent_count' do
    context 'JMeter threads more than maximum threads per agent' do
      it 'should be more than 1' do
        jmeter_plan = mock(Hailstorm::Model::JmeterPlan, num_threads: 1000)
        @aws.max_threads_per_agent = 50
        expect(@aws.required_load_agent_count(jmeter_plan)).to be > 1
      end
    end
    context 'JMeter threads less than maximum threads per agent' do
      it 'should be equal to 1' do
        jmeter_plan = mock(Hailstorm::Model::JmeterPlan, num_threads: 10)
        @aws.max_threads_per_agent = 50
        expect(@aws.required_load_agent_count(jmeter_plan)).to be == 1
      end
    end
  end

  context '#identity_file_exists' do
    before(:each) do
      @aws.project = Hailstorm::Model::Project.new(project_code: 'amazon_cloud_spec')
    end

    context 'identity_file_path does not exist' do
      before(:each) do
        @aws.stub!(:identity_file_path).and_return('/dev/null')
        File.stub!(:exist?).and_return(false)
        @aws.ssh_identity = 'secure'
        @mock_key_pair_client = mock(Hailstorm::Behavior::AwsAdaptable::KeyPairClient)
        @aws.stub!(:key_pair_client).and_return(@mock_key_pair_client)
        @mock_key_pair = Hailstorm::Behavior::AwsAdaptable::KeyPair.new(key_material: 'A', key_name: 'mock_key_pair')
      end

      context 'ec2 key_pair exists' do
        it 'should add an error on ssh_identity' do
          @mock_key_pair_client.stub!(:find).and_return(@mock_key_pair)
          @mock_key_pair_client.should_receive(:delete)
          @aws.should_receive(:create_key_pair)
          @aws.send(:identity_file_exists)
        end
      end

      context 'ec2 key_pair does not exist' do
        it 'should create the ec2 key_pair' do
          @mock_key_pair_client.stub!(:find).and_return(nil)
          @mock_key_pair_client.stub!(:create).and_return(@mock_key_pair)
          @mock_key_pair.should_receive(:private_key)
          File.stub!(:chmod)
          @aws.send(:identity_file_exists)
        end
      end
    end
  end

  context '#create_agent_ami' do
    context 'ami_creation_needed? == true' do
      before(:each) do
        @aws.active = true
        @aws.project = Hailstorm::Model::Project.create!(project_code: 'amazon_cloud_spec')
        @aws.ssh_identity = 'secure'
        @aws.instance_type = 'm1.small'
        @aws.region = 'us-east-1'
        @aws.security_group = 'sg-12345'
        @aws.vpc_subnet_id = 'subnet-1234'
        @aws.stub!(:ami_creation_needed?).and_return(true)
        @aws.stub!(:find_vpc).and_return('vpc-123')

        mock_sg_client = mock(Hailstorm::Behavior::AwsAdaptable::SecurityGroupClient)
        mock_security_group = Hailstorm::Behavior::AwsAdaptable::SecurityGroup.new(group_id: @aws.security_group)
        mock_sg_client.stub!(:find).and_return(mock_security_group)
        @aws.stub!(:security_group_client).and_return(mock_sg_client)

        @mock_instance_client = mock(Hailstorm::Behavior::AwsAdaptable::InstanceClient)
        @aws.stub!(:instance_client).and_return(@mock_instance_client)
        mock_instance = Hailstorm::Behavior::AwsAdaptable::Instance.new(
          instance_id: 'i-23456',
          public_ip_address: '10.34.56.45',
          private_ip_address: '172.16.0.10',
          state: Hailstorm::Behavior::AwsAdaptable::InstanceState.new(name: 'shutting-down')
        )

        @mock_instance_client.stub!(:create).and_return(mock_instance)
        @mock_instance_client.stub!(:find).and_return(mock_instance)
        @mock_instance_client.stub!(:terminated?).and_return(true)
        @mock_instance_client.stub!(:ready?).and_return(true)
        Hailstorm::Support::SSH.stub!(:ensure_connection).and_return(true)
      end

      context 'ami build fails' do
        it 'should raise an exception' do
          @aws.stub!(:provision)
          @aws.stub!(:register_hailstorm_ami).and_raise(StandardError, 'mocked exception')
          @mock_instance_client.should_receive(:terminate)
          expect { @aws.send(:create_agent_ami) }.to raise_error
        end
      end

      context 'ami build succeeds' do
        it 'should assign the AMI id' do
          @aws.stub!(:provision)
          mock_ec2_image = Hailstorm::Behavior::AwsAdaptable::Ami.new(image_id: 'ami-12334',
                                                                      state: 'available',
                                                                      name: 'same_owner/other_image')
          @aws.stub!(:register_hailstorm_ami).and_return(mock_ec2_image.id)
          @mock_instance_client.should_receive(:terminate)
          @aws.send(:create_agent_ami)
          expect(@aws.agent_ami).to eql(mock_ec2_image.id)
        end
      end
    end
  end

  context '#install_java' do
    it 'should collect remote stdout' do
      @aws.stub!(:ssh_channel_exec_instr) do |_ssh, instr,  cb|
        cb.call("#{instr} ok")
        true
      end
      expect(@aws.send(:install_java, double('ssh'))).to_not be_empty
    end
    it 'should raise error if installation fails' do
      @aws.stub!(:ssh_channel_exec_instr).and_return(nil)
      expect { @aws.send(:install_java, double('ssh')) }
        .to raise_error(Hailstorm::JavaInstallationException) { |error| expect(error.diagnostics).to_not be_blank }
    end
  end

  context '#install_jmeter' do
    it 'should execute installer commands' do
      @aws.project = Hailstorm::Model::Project.create!(project_code: __FILE__)
      mock_ssh = double('Mock SSH')
      mock_ssh.should_receive(:exec!).at_least(:once)
      @aws.send(:install_jmeter, mock_ssh)
    end
  end

  context '#check_for_existing_ami' do
    context 'an AMI exists' do
      it 'should assign the AMI id to agent_ami' do
        @aws.project = Hailstorm::Model::Project.create!(project_code: __FILE__)
        mock_ami_client = mock(Hailstorm::Behavior::AwsAdaptable::AmiClient)
        mock_ec2_ami = Hailstorm::Behavior::AwsAdaptable::Ami.new(state: 'available', name: @aws.send(:ami_id), ami_id: 'ami-123')
        mock_ami_client.stub!(:find_self_owned).and_return(mock_ec2_ami)
        @aws.stub!(:ami_client).and_return(mock_ami_client)
        @aws.send(:check_for_existing_ami)
        expect(@aws.agent_ami).to be == mock_ec2_ami.id
      end
    end
  end

  context '#set_availability_zone' do
    context 'JMeter run in master-slave mode' do
      context 'zone is not assigned' do
        it 'should assign the first available zone' do
          @aws.project = Hailstorm::Model::Project.new(project_code: __FILE__, master_slave_mode: true)
          mock_ec2_client = mock(Hailstorm::Behavior::AwsAdaptable::Ec2Client)
          mock_ec2_client.stub!(:first_available_zone).and_return('us-east-1a')
          @aws.stub!(:ec2_client).and_return(mock_ec2_client)
          @aws.send(:set_availability_zone)
          expect(@aws.zone).to be == 'us-east-1a'
        end
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

      mock_cleaner = mock(Hailstorm::Support::AmazonAccountCleaner)
      mock_cleaner.should_receive(:cleanup)
      clusterable.purge(mock_cleaner)
      expect(clusterable.agent_ami).to be_nil
    end
  end

  context '#before_generate_load' do
    it 'should start the agents' do
      @aws.access_key = 'dummy'
      @aws.secret_key = 'dummy'
      @aws.vpc_subnet_id = 'subnet-1234'
      @aws.project = Hailstorm::Model::Project.new(project_code: __FILE__)
      stub_aws!(@aws)
      jmeter_plan = Hailstorm::Model::JmeterPlan.create!(
        project: @aws.project,
        test_plan_name: 'sample',
        content_hash: 'A',
        active: false
      )
      jmeter_plan.update_column(:active, true)
      @aws.save!
      3.times do
        agent = Hailstorm::Model::MasterAgent.create!(
          clusterable_id: @aws.id,
          clusterable_type: @aws.class.name,
          jmeter_plan: jmeter_plan,
          active: false
        )
        agent.update_column(:active, true)
      end
      @aws.should_receive(:start_agent).exactly(3).times
      @aws.before_generate_load
    end
  end

  context '#create_agent' do
    it 'should run a new EC2 instance' do
      @aws.security_group = 'sg-a'
      mock_sg_client = mock(Hailstorm::Behavior::AwsAdaptable::SecurityGroupClient)
      @aws.stub!(:security_group_client).and_return(mock_sg_client)
      mock_sg_client.stub!(:find) do |kwargs|
        Hailstorm::Behavior::AwsAdaptable::SecurityGroup.new(group_id: kwargs[:name])
      end

      @aws.should_receive(:new_ec2_instance_attrs) do |_arg1, arg2|
        expect(arg2).to eql(%w[sg-a])
      end

      @aws.should_receive(:create_ec2_instance)
      @aws.create_agent
    end
  end

  context '#ssh_channel_exec_instr' do
    it 'should return instruction execution status' do
      mock_channel = double('Mock SSH Channel')
      mock_channel.stub!(:on_data).and_yield(mock_channel, 'instruction output')
      mock_channel.stub!(:on_extended_data).and_yield(mock_channel, $stderr, nil)
      mock_channel.stub!(:wait)
      mock_channel.stub!(:exec) do |&block|
        block.call(mock_channel, true)
      end
      mock_ssh = mock(Net::SSH)
      mock_ssh.stub!(:open_channel) do |&block|
        block.call(mock_channel)
        mock_channel
      end
      out = ''
      status = @aws.send(:ssh_channel_exec_instr, mock_ssh, 'ls', ->(s) { out += s.to_s })
      expect(status).to be_true
      expect(out).to_not be_empty
    end
  end

  context '#provision' do
    it 'should install Hailstorm dependencies on the ec2 instance' do
      mock_instance = Hailstorm::Behavior::AwsAdaptable::Instance.new(public_ip_address: '120.34.35.58')
      mock_ssh = mock(Net::SSH)
      Hailstorm::Support::SSH.stub!(:start).and_yield(mock_ssh)
      @aws.should_receive(:install_java).with(mock_ssh)
      @aws.should_receive(:install_jmeter).with(mock_ssh)
      @aws.stub!(:identity_file_path).and_return(__FILE__)
      @aws.send(:provision, mock_instance)
    end
  end

  context '#register_hailstorm_ami' do
    before(:each) do
      @aws.project = Hailstorm::Model::Project.create!(project_code: __FILE__)
      @mock_instance = Hailstorm::Behavior::AwsAdaptable::Instance.new(instance_id: 'i-67678')
      @mock_ami_client = mock(Hailstorm::Behavior::AwsAdaptable::AmiClient)
      @aws.stub!(:ami_client).and_return(@mock_ami_client)
    end

    it 'should create an AMI from the instance state' do
      mock_ami = Hailstorm::Behavior::AwsAdaptable::Ami.new(state: 'available', image_id: 'ami-123', name: 'hailstorm')
      @mock_ami_client.stub!(:register_ami).and_return(mock_ami.id)
      @mock_ami_client.stub!(:available?).and_return(true)
      ami_id = @aws.send(:register_hailstorm_ami, @mock_instance)
      expect(ami_id).to eql(mock_ami.image_id)
    end

    context 'on failure' do
      it 'should raise exception' do
        @mock_ami_client.stub!(:register_ami).and_return('ami-123')
        @aws.stub!(:wait_for).and_raise(Hailstorm::Exception, 'mock waiter error')
        state_reason = Hailstorm::Behavior::AwsAdaptable::StateReason.new(code: '10',
                                                                          message: 'mock AMI creation failure')
        mock_ami = Hailstorm::Behavior::AwsAdaptable::Ami.new(state: 'failed',
                                                              image_id: 'ami-123',
                                                              name: 'hailstorm',
                                                              state_reason: state_reason)
        @mock_ami_client.stub!(:find).and_return(mock_ami)
        expect { @aws.send(:register_hailstorm_ami, @mock_instance) }.to raise_error(Hailstorm::AmiCreationFailure)
        begin
          @aws.send(:register_hailstorm_ami, @mock_instance)
        rescue Hailstorm::AmiCreationFailure => amiFailure
          expect(amiFailure.diagnostics).to_not be_blank
        end
      end
    end
  end

  context Hailstorm::Behavior::Provisionable do
    context '#agent_before_save_on_create' do
      it 'should start_agent' do
        @aws.should_receive(:start_agent)
        @aws.agent_before_save_on_create(nil)
      end
    end

    context '#agents_to_add' do
      context 'required and current count is same' do
        it 'should return 0' do
          query = mock(ActiveRecord::Relation, count: 5)
          expect(@aws.agents_to_add(query, 5) { }).to be_zero
        end
      end
      context 'required count is greater than the current count' do
        it 'should yield and return the differential' do
          query = mock(ActiveRecord::Relation, count: 3)
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
          @aws.stub!(:start_agent)
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

          Hailstorm::Model::LoadAgent.any_instance.stub(:upload_scripts)
          agent = Hailstorm::Model::MasterAgent.create!(
            clusterable_id: @aws.id,
            clusterable_type: @aws.class.name,
            jmeter_plan: jmeter_plan
          )

          jmeter_plan.stub!(:num_threads).and_return(30)

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
        Hailstorm::Model::JmeterPlan.any_instance.stub(:num_threads).and_return(50)
        Hailstorm::Model::LoadAgent.any_instance.stub(:upload_scripts)
        stub_aws!(@aws)
        @aws.unstub!(:provision_agents)

        @aws.stub!(:start_agent)
        @aws.project = Hailstorm::Model::Project.create!(project_code: 'amazon_cloud_spec')
        @aws.access_key = 'foo'
        @aws.secret_key = 'bar'
        @aws.vpc_subnet_id = 'subnet-1234'
        @aws.max_threads_per_agent = 50
        @aws.save!

        jmeter_plan_1 = Hailstorm::Model::JmeterPlan.create!(
            project: @aws.project,
            test_plan_name: 'sample A',
            content_hash: 'A',
            active: false
        )

        jmeter_plan_1.update_column(:active, true)

        jmeter_plan_2 = Hailstorm::Model::JmeterPlan.create!(
            project: @aws.project,
            test_plan_name: 'sample B',
            content_hash: 'B',
            active: false
        )

        jmeter_plan_2.update_column(:active, true)

        @aws.update_column(:active, true)
        @aws.provision_agents
        expect(Hailstorm::Model::MasterAgent.count).to be == 2

        jmeter_plan_2.update_attribute(:active, false)

        @aws.update_column(:active, false)
        @aws.max_threads_per_agent = 25
        @aws.save!

        @aws.update_column(:active, true)
        @aws.provision_agents
        expect(Hailstorm::Model::MasterAgent.count).to be == 3
        expect(Hailstorm::Model::MasterAgent.where(jmeter_plan_id: jmeter_plan_2.id).count).to be == 1
        expect(Hailstorm::Model::MasterAgent.where(jmeter_plan_id: jmeter_plan_2.id).first).to_not be_active
        expect(Hailstorm::Model::MasterAgent.where(jmeter_plan_id: jmeter_plan_1.id, active: true).count).to be == 2
      end
    end
  end

  context '#assign_vpc_subnet' do
    it 'should create a Hailstorm public subnet if it does not exist' do
      mock_vpc_client = mock(Hailstorm::Behavior::AwsAdaptable::VpcClient)
      @aws.stub!(:vpc_client).and_return(mock_vpc_client)
      mock_vpc_client.stub!(:modify_attribute)
      mock_vpc_client.stub!(:tag_name)
      mock_vpc_client.stub!(:available?).and_return(true)
      mock_vpc_client.stub!(:create).and_return('vpc-123')

      mock_subnet_client = mock(Hailstorm::Behavior::AwsAdaptable::SubnetClient)
      @aws.stub!(:subnet_client).and_return(mock_subnet_client)
      mock_subnet_client.stub!(:find).and_return(nil)
      mock_subnet_client.stub!(:tag_name)
      mock_subnet_client.stub!(:available?).and_return(true)
      mock_subnet_client.stub!(:modify_attribute)
      mock_subnet_client.stub!(:create).and_return('subnet-123')

      mock_igw_client = mock(Hailstorm::Behavior::AwsAdaptable::InternetGatewayClient)
      @aws.stub!(:internet_gateway_client).and_return(mock_igw_client)
      mock_igw_client.stub!(:tag_name)
      mock_igw_client.stub!(:attach)
      mock_igw_client.stub!(:create).and_return('igw-123')

      mock_rt_client = mock(Hailstorm::Behavior::AwsAdaptable::RouteTableClient)
      @aws.stub!(:route_table_client).and_return(mock_rt_client)
      mock_rt_client.stub!(:create_route)
      mock_rt_client.stub!(:associate_with_subnet)
      mock_rt_client.stub!(:main_route_table).and_return('route-123')
      route = Hailstorm::Behavior::AwsAdaptable::Route.new(state: 'active')
      mock_rt_client.stub!(:routes).and_return([route])

      @aws.send(:assign_vpc_subnet)
      expect(@aws.vpc_subnet_id).to be == 'subnet-123'
    end
  end
end
