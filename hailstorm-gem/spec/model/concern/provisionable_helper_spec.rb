require 'spec_helper'
require 'hailstorm/model/concern/provisionable_helper'
require 'hailstorm/model/amazon_cloud'

describe Hailstorm::Model::Concern::ProvisionableHelper do

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

  context '#create_agent' do
    it 'should run a new EC2 instance' do
      @aws.agent_ami = 'ami-123456'
      security_group = Hailstorm::Behavior::AwsAdaptable::SecurityGroup.new(group_id: 'sg-123456')
      mock_sg_finder = mock(Hailstorm::Model::Helper::SecurityGroupFinder)
      mock_sg_finder.stub!(:find_security_group).and_return(security_group)
      @aws.stub!(:security_group_finder).and_return(mock_sg_finder)

      mock_ec2_instance_helper = mock(Hailstorm::Model::Helper::Ec2InstanceHelper)
      @aws.stub!(:ec2_instance_helper).and_return(mock_ec2_instance_helper)
      mock_ec2_instance_helper.should_receive(:create_ec2_instance)
          .with(ami_id: @aws.agent_ami, security_group_ids: security_group.id)
      @aws.send(:create_agent)
    end
  end
end
