# frozen_string_literal: true

require 'spec_helper'

require 'hailstorm/behavior/clusterable'
require 'hailstorm/model/cluster'
require 'hailstorm/model/project'
require 'hailstorm/model/amazon_cloud'
require 'hailstorm/model/data_center'
require 'hailstorm/model/jmeter_plan'
require 'hailstorm/model/master_agent'
require 'hailstorm/model/slave_agent'
require 'hailstorm/support/configuration'

require 'active_record/base'

module Hailstorm
  module Model
    class TestCluster < ActiveRecord::Base
      include Hailstorm::Behavior::Clusterable
      def setup(*args)
        # noop
      end
    end
  end
end

class Hailstorm::Support::Configuration
  class TestCluster < Hailstorm::Support::Configuration::ClusterBase
    attr_accessor :name
  end
end

def clusterables_stub!
  klasses = [Hailstorm::Model::AmazonCloud, Hailstorm::Model::DataCenter]
  common_instance_methods = %i[
    setup
    before_generate_load
    start_slave_process
    start_master_process
    after_generate_load
    before_stop_load_generation
    stop_master_process
    after_stop_load_generation
    cleanup
    purge
    transfer_identity_file
  ]

  common_instance_methods.each do |m|
    klasses.each { |k| allow_any_instance_of(k).to receive(m) }
  end

  klasses.each do |k|
    allow_any_instance_of(k).to receive(:check_status).and_return([instance_double(Hailstorm::Model::MasterAgent)])
  end

  amz_instance_methods = %i[
    identity_file_exists
    create_security_group
    create_agent_ami
    set_availability_zone
    assign_vpc_subnet
    before_destroy_load_agent
    after_destroy_load_agent
  ]

  amz_instance_methods.each do |m|
    allow_any_instance_of(Hailstorm::Model::AmazonCloud).to receive(m)
  end
end

describe Hailstorm::Model::Cluster do
  before(:each) do
    @project = Hailstorm::Model::Project.where(project_code: 'cluster_spec').first_or_create!
  end

  context '.configure_all' do
    context '#active=true' do
      it 'should get persisted' do
        config = Hailstorm::Support::Configuration.new
        config.clusters(:test_cluster) do |cluster|
          cluster.user_name = 'jed'
          cluster.name = 'active_cluster'
        end
        Hailstorm::Model::Cluster.configure_all(@project, config)
        expect(Hailstorm::Model::Cluster.where(project_id: @project.id).count).to eql(1)
      end
    end
    context '#active=false' do
      it 'should get persisted' do
        config = Hailstorm::Support::Configuration.new
        config.clusters(:test_cluster) do |cluster|
          cluster.user_name = 'jed'
          cluster.name = 'inactive_cluster'
          cluster.active = false
        end
        Hailstorm::Model::Cluster.configure_all(@project, config)
        expect(Hailstorm::Model::Cluster.where(project_id: @project.id).count).to eql(1)
      end
    end
    context 'multiple clusterables' do
      it 'should configure all clusters' do
        config = Hailstorm::Support::Configuration.new
        config.clusters(:amazon_cloud) do |aws|
          aws.access_key = 'key-1'
          aws.secret_key = 'secret-1'
          aws.region = 'us-east-1'
        end
        config.clusters(:amazon_cloud) do |aws|
          aws.access_key = 'key-2'
          aws.secret_key = 'secret-2'
          aws.region = 'us-east-2'
        end
        config.clusters(:data_center) do |dc|
          dc.machines = %w[A B C]
          dc.user_name = 'alice'
          dc.ssh_identity = 'identity-1'
          dc.title = 'DC-A'
        end
        config.clusters(:data_center) do |dc|
          dc.machines = %w[D E F]
          dc.user_name = 'bob'
          dc.ssh_identity = 'identity-2'
          dc.title = 'DC-B'
        end

        clusterables_stub!
        Hailstorm::Model::Cluster.configure_all(@project, config)
        expect(Hailstorm::Model::Cluster.where(project_id: @project.id).count).to eql(4)
      end
    end
    context 'reconfiguration' do
      it 'should configure all clusters' do
        clusterables_stub!
        config = Hailstorm::Support::Configuration.new
        config.clusters(:amazon_cloud) do |aws|
          aws.access_key = 'key-1'
          aws.secret_key = 'secret-1'
          aws.region = 'us-east-1'
        end
        Hailstorm::Model::Cluster.configure_all(@project, config)

        config = Hailstorm::Support::Configuration.new
        config.clusters(:amazon_cloud) do |aws|
          aws.access_key = 'key-1'
          aws.secret_key = 'secret-1'
          aws.region = 'us-east-1'
        end
        Hailstorm::Model::Cluster.configure_all(@project, config)

        expect(Hailstorm::Model::Cluster.where(project_id: @project.id).count).to eql(1)
      end
    end
    context 'additional configuration of a cluster' do
      it 'should configure all clusters' do
        clusterables_stub!
        config = Hailstorm::Support::Configuration.new
        config.clusters(:amazon_cloud) do |aws|
          aws.access_key = 'key-1'
          aws.secret_key = 'secret-1'
          aws.region = 'us-east-1'
        end
        Hailstorm::Model::Cluster.configure_all(@project, config)

        config = Hailstorm::Support::Configuration.new
        config.clusters(:amazon_cloud) do |aws|
          aws.access_key = 'key-1'
          aws.secret_key = 'secret-1'
          aws.region = 'us-east-1'
        end
        config.clusters(:amazon_cloud) do |aws|
          aws.access_key = 'key-2'
          aws.secret_key = 'secret-2'
          aws.region = 'us-east-2'
        end
        Hailstorm::Model::Cluster.configure_all(@project, config)

        expect(Hailstorm::Model::Cluster.where(project_id: @project.id).count).to eql(2)
      end
    end
    context 'reconfiguration with mutable properties' do
      it 'should not create duplicate clusters' do
        clusterables_stub!
        config = Hailstorm::Support::Configuration.new
        config.clusters(:amazon_cloud) do |aws|
          aws.access_key = 'key-1'
          aws.secret_key = 'secret-1'
          aws.region = 'us-east-1'
        end

        Hailstorm::Model::Cluster.configure_all(@project, config)

        config.clusters(:amazon_cloud) do |aws|
          aws.access_key = 'key-1'
          aws.secret_key = 'secret-1'
          aws.region = 'us-east-1'
          aws.max_threads_per_agent = 500
        end

        Hailstorm::Model::Cluster.configure_all(@project, config)
        expect(@project.reload.clusters.count).to be == 1
      end
    end
  end

  context '#configure' do
    context ':amazon_cloud' do
      it 'should persist all configuration options' do
        allow_any_instance_of(Hailstorm::Model::AmazonCloud).to receive(:transfer_identity_file)
        config = Hailstorm::Support::Configuration.new
        config.clusters(:amazon_cloud) do |aws|
          aws.access_key = 'blah'
          aws.secret_key = 'blahblah'
          aws.ssh_identity = 'insecure'
          aws.ssh_port = 8022
          aws.active = false
        end
        cluster = Hailstorm::Model::Cluster.new(cluster_type: Hailstorm::Model::AmazonCloud.to_s)
        cluster.project = Hailstorm::Model::Project.where(project_code: 'cluster_spec').first_or_create!
        cluster.save!
        cluster.configure(config.clusters.first)
        amz_cloud = Hailstorm::Model::AmazonCloud.where(project_id: cluster.project.id)
        expect(amz_cloud.first).to_not be_nil
        expect(amz_cloud.first.ssh_port).to eql(8022)
      end
    end
    context ':data_center' do
      [%w[192.168.20.10], %w[192.168.20.10 192.168.20.20]].each do |machines|
        it "should persist all configuration options with #{machines}" do
          config = Hailstorm::Support::Configuration.new
          config.clusters(:data_center) do |dc|
            dc.title = 'Cluster One'
            dc.user_name = 'root'
            dc.ssh_identity = '1/insecure.pem'
            dc.machines = machines
            dc.active = false
          end

          cluster = Hailstorm::Model::Cluster.new(cluster_type: Hailstorm::Model::DataCenter.to_s)
          cluster.project = Hailstorm::Model::Project.where(project_code: 'cluster_spec').first_or_create!
          cluster.save!
          cluster.configure(config.clusters.first)
          dc = Hailstorm::Model::DataCenter.where(project_id: cluster.project.id).first
          expect(dc).to_not be_nil
          expect(dc.machines).to eql(machines)
        end
      end
    end
  end

  context '.generate_all_load' do
    before(:each) do
      @config = Hailstorm::Support::Configuration.new
      @config.clusters(:amazon_cloud) do |aws|
        aws.access_key = 'key-1'
        aws.secret_key = 'secret-1'
        aws.region = 'us-east-1'
        aws.active = true
      end
      @config.clusters(:data_center) do |dc|
        dc.machines = %w[A]
        dc.user_name = 'alice'
        dc.ssh_identity = 'identity-1'
        dc.title = 'DC-A'
        dc.active = true
      end

      clusterables_stub!
    end
    context 'without master_slave setup' do
      it 'should generate load on all active clusters' do
        @config.clusters(:data_center) do |dc|
          dc.machines = %w[B]
          dc.user_name = 'bob'
          dc.ssh_identity = 'identity-1'
          dc.title = 'DC-B'
          dc.active = false
        end

        Hailstorm::Model::Cluster.configure_all(@project, @config)
        @project.build_current_execution_cycle.save!
        @project.current_execution_cycle.started!
        cluster_instances = Hailstorm::Model::Cluster.generate_all_load(@project)
        expect(cluster_instances.length).to eql(@config.clusters.length - 1)
      end
    end
    context 'with master_slave setup' do
      it 'should generate load on all active clusters' do
        @project.update_column(:master_slave_mode, true)
        Hailstorm::Model::Cluster.configure_all(@project, @config)
        @project.build_current_execution_cycle.save!
        @project.current_execution_cycle.started!
        cluster_instances = Hailstorm::Model::Cluster.generate_all_load(@project)
        expect(cluster_instances.length).to eql(@config.clusters.length)
      end
    end
  end

  context '.check_status' do
    it 'should report cluster status' do
      config = Hailstorm::Support::Configuration.new
      config.clusters(:amazon_cloud) do |aws|
        aws.access_key = 'key-1'
        aws.secret_key = 'secret-1'
        aws.region = 'us-east-1'
        aws.active = true
      end
      config.clusters(:data_center) do |dc|
        dc.machines = %w[A]
        dc.user_name = 'alice'
        dc.ssh_identity = 'identity-1'
        dc.title = 'DC-A'
        dc.active = true
      end

      clusterables_stub!

      Hailstorm::Model::Cluster.configure_all(@project, config)
      @project.build_current_execution_cycle.save!
      @project.current_execution_cycle.started!
      Hailstorm::Model::Cluster.generate_all_load(@project)

      agents = Hailstorm::Model::Cluster.check_status(@project)
      expect(agents.size).to be == 2
    end
  end

  context '.stop_load_generation' do
    before(:each) do
      @jmeter_plan = Hailstorm::Model::JmeterPlan.create!(project: @project,
                                                          test_plan_name: 'a.jmx',
                                                          content_hash: 'A',
                                                          active: false,
                                                          properties: '{}')

      @jmeter_plan.update_column(:active, true)
    end

    it 'should stop load generation on all active clusters' do
      config = Hailstorm::Support::Configuration.new
      config.clusters(:amazon_cloud) do |aws|
        aws.access_key = 'key-1'
        aws.secret_key = 'secret-1'
        aws.region = 'us-east-1'
        aws.active = true
      end

      config.clusters(:amazon_cloud) do |aws|
        aws.access_key = 'key-2'
        aws.secret_key = 'secret-2'
        aws.region = 'us-west-1'
        aws.active = false
      end

      config.clusters(:data_center) do |dc|
        dc.machines = %w[A]
        dc.user_name = 'alice'
        dc.ssh_identity = 'identity-1'
        dc.title = 'DC-A'
        dc.active = true
      end

      clusterables_stub!
      @project.build_current_execution_cycle.save!

      Hailstorm::Model::Cluster.configure_all(@project, config)
      @project.current_execution_cycle.started!
      Hailstorm::Model::Cluster.generate_all_load(@project)

      @project.clusters.all.each do |cluster|
        Hailstorm::Model::MasterAgent.create!(clusterable_id: cluster.clusterable_id,
                                              clusterable_type: cluster.cluster_type,
                                              jmeter_plan: @jmeter_plan,
                                              public_ip_address: '2.3.4.5')
      end

      allow(Hailstorm::Model::ClientStat).to receive(:collect_client_stats)
      cluster_instances = Hailstorm::Model::Cluster.stop_load_generation(@project)
      expect(cluster_instances.size).to eq(config.clusters.size - 1)
    end

    context 'fail on a cluster' do
      it 'should raise exception' do
        config = Hailstorm::Support::Configuration.new
        config.clusters(:amazon_cloud) do |aws|
          aws.access_key = 'key-1'
          aws.secret_key = 'secret-1'
          aws.region = 'us-east-1'
          aws.active = true
        end

        clusterables_stub!
        @project.build_current_execution_cycle.save!

        Hailstorm::Model::Cluster.configure_all(@project, config)
        @project.current_execution_cycle.started!
        Hailstorm::Model::Cluster.generate_all_load(@project)

        cluster = @project.clusters.reload.first
        Hailstorm::Model::MasterAgent.create!(clusterable_id: cluster.clusterable_id,
                                              clusterable_type: cluster.cluster_type,
                                              jmeter_plan: @jmeter_plan,
                                              public_ip_address: '2.3.4.5',
                                              jmeter_pid: '2344')

        allow(Hailstorm::Model::ClientStat).to receive(:collect_client_stats)
        expect { Hailstorm::Model::Cluster.stop_load_generation(@project) }.to raise_error(Hailstorm::Exception)
      end
    end
  end

  context '.terminate' do
    it 'should terminate all clusters' do
      config = Hailstorm::Support::Configuration.new
      config.clusters(:amazon_cloud) do |aws|
        aws.access_key = 'key-1'
        aws.secret_key = 'secret-1'
        aws.region = 'us-east-1'
        aws.active = true
      end
      config.clusters(:data_center) do |dc|
        dc.machines = %w[A]
        dc.user_name = 'alice'
        dc.ssh_identity = 'identity-1'
        dc.title = 'DC-A'
        dc.active = true
      end

      clusterables_stub!
      mock_agent = instance_spy(Hailstorm::Model::LoadAgent)
      allow(mock_agent).to receive(:transaction).and_yield
      allow_any_instance_of(Hailstorm::Model::AmazonCloud).to receive_message_chain(
        :load_agents, :all
      ).and_return([mock_agent])

      Hailstorm::Model::Cluster.configure_all(@project, config)
      expect(Hailstorm::Model::AmazonCloud.count).to be > 0
      expect(Hailstorm::Model::DataCenter.count).to be > 0

      Hailstorm::Model::Cluster.terminate(@project)
      expect(Hailstorm::Model::LoadAgent.count).to be_zero
    end
  end

  context '#purge' do
    it 'should purge all active clusters' do
      config = Hailstorm::Support::Configuration.new
      config.clusters(:amazon_cloud) do |aws|
        aws.access_key = 'key-1'
        aws.secret_key = 'secret-1'
        aws.region = 'us-east-1'
        aws.active = true
      end

      clusterables_stub!
      Hailstorm::Model::Cluster.configure_all(@project, config)
      expect_any_instance_of(Hailstorm::Model::AmazonCloud).to receive(:purge)
      Hailstorm::Model::Cluster.first.purge
    end

    it 'should not purge inactive clusters' do
      config = Hailstorm::Support::Configuration.new
      config.clusters(:amazon_cloud) do |aws|
        aws.access_key = 'key-1'
        aws.secret_key = 'secret-1'
        aws.region = 'us-east-1'
        aws.active = false
      end

      clusterables_stub!
      Hailstorm::Model::Cluster.configure_all(@project, config)
      expect_any_instance_of(Hailstorm::Model::AmazonCloud).to_not receive(:purge)
      Hailstorm::Model::Cluster.first.purge
    end
  end

  context '#cluster_klass' do
    context 'unknown class' do
      it 'should raise LoadError' do
        cluster = Hailstorm::Model::Cluster.new(cluster_type: 'foo')
        expect { cluster.cluster_klass }.to raise_error(LoadError)
      end
    end
  end

  context '#destroy_clusterable' do
    it 'should destroy the associated cluster' do
      config = Hailstorm::Support::Configuration.new
      config.clusters(:amazon_cloud) do |aws|
        aws.access_key = 'key-1'
        aws.secret_key = 'secret-1'
        aws.region = 'us-east-1'
        aws.active = true
      end

      clusterables_stub!
      Hailstorm::Model::Cluster.configure_all(@project, config)
      expect(Hailstorm::Model::AmazonCloud.count).to be == 1
      Hailstorm::Model::Cluster.first.destroy!
      expect(Hailstorm::Model::AmazonCloud.count).to be_zero
    end

    it 'should not raise if record not found' do
      config = Hailstorm::Support::Configuration.new
      config.clusters(:amazon_cloud) do |aws|
        aws.access_key = 'key-1'
        aws.secret_key = 'secret-1'
        aws.region = 'us-east-1'
        aws.active = true
      end

      clusterables_stub!
      allow_any_instance_of(Hailstorm::Model::AmazonCloud).to receive(:destroy!).and_raise(ActiveRecord::RecordNotFound,
                                                                                           'mock not found error')

      Hailstorm::Model::Cluster.configure_all(@project, config)
      expect { Hailstorm::Model::Cluster.first.destroy! }.to_not raise_error
    end
  end

  context '#cluster_instance' do
    context '#clusterable_id is nil' do
      it 'should initialize a new cluster instance' do
        cluster = Hailstorm::Model::Cluster.new(cluster_type: Hailstorm::Model::AmazonCloud.name)
        expect(cluster.cluster_instance(region: 'us-east-1')).to be_a(Hailstorm::Model::AmazonCloud)
      end
    end
  end

  context Hailstorm::Behavior::Clusterable do
    context '#start_jmeter_process' do
      it 'should start jmeter on iterated agents' do
        agent = Hailstorm::Model::MasterAgent.new
        expect(agent).to receive(:upload_scripts)
        expect(agent).to receive(:start_jmeter)
        clusterable = Hailstorm::Model::DataCenter.new
        clusterable.start_jmeter_process([agent], true)
      end
    end

    context '#start_slave_process' do
      it 'should start jmeter on all slaves' do
        clusterable = Hailstorm::Model::DataCenter.new
        expect(clusterable).to respond_to(:slave_agents)
        agent = Hailstorm::Model::SlaveAgent.new
        allow(clusterable).to receive_message_chain(:slave_agents, :where).and_return([agent])
        expect(clusterable).to receive(:start_jmeter_process)
        clusterable.start_slave_process
      end
    end

    context '#start_master_process' do
      it 'should start jmeter on all masters' do
        clusterable = Hailstorm::Model::DataCenter.new
        expect(clusterable).to respond_to(:master_agents)
        agent = Hailstorm::Model::MasterAgent.new
        allow(clusterable).to receive_message_chain(:master_agents, :where).and_return([agent])
        expect(clusterable).to receive(:start_jmeter_process)
        clusterable.start_master_process
      end
    end

    context '#stop_master_process' do
      it 'should stop jmeter on all master agents' do
        clusterable = Hailstorm::Model::DataCenter.new
        expect(clusterable).to respond_to(:master_agents)
        agent = Hailstorm::Model::MasterAgent.new
        allow(clusterable).to receive_message_chain(:master_agents, :where, :all).and_return([agent])
        expect(agent).to receive(:stop_jmeter).with(wait: false, aborted: false)
        clusterable.stop_master_process
      end
    end

    context '#process_jmeter_plan' do
      before(:each) do
        @clusterable = Hailstorm::Model::DataCenter.new
        @jmeter_plan = instance_double(Hailstorm::Model::JmeterPlan, id: 1)
        allow(@clusterable).to receive(:master_slave_relation).and_return(:master_agents)
      end
      context '#create_or_enable fails with Hailstorm::Exception' do
        it 'should raise the same error' do
          allow(@clusterable).to receive(:create_or_enable).and_raise(Hailstorm::Exception, 'mock exception')
          expect { @clusterable.process_jmeter_plan(@jmeter_plan) }.to raise_error(Hailstorm::Exception)
        end
      end
      context '#create_or_enable fails with exception outside of Hailstorm::Exception hierarchy' do
        it 'should raise Hailstorm::AgentCreationFailure' do
          allow(@clusterable).to receive(:create_or_enable).and_raise(Exception, 'mock exception')
          expect { @clusterable.process_jmeter_plan(@jmeter_plan) }
            .to raise_error(Hailstorm::AgentCreationFailure) { |error| expect(error.diagnostics).to_not be_blank }
        end
      end
    end

    context '#provision_agents' do
      it 'process active jmeter_plans in project' do
        clusterable = Hailstorm::Model::DataCenter.new
        allow(clusterable).to receive(:destroyed?).and_return(false)
        allow(clusterable).to receive(:project).and_return(@project)
        expect(@project).to respond_to(:jmeter_plans)
        jmeter_plans = [instance_double(Hailstorm::Model::JmeterPlan, id: 1)]
        allow(@project).to receive_message_chain(:jmeter_plans, :where, :all).and_return(jmeter_plans)
        expect(clusterable).to receive(:process_jmeter_plan).and_return([])
        clusterable.provision_agents
      end
    end
  end
end
