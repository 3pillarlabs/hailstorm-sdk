require 'spec_helper'

require 'hailstorm/behavior/clusterable'
require 'hailstorm/model/cluster'
require 'hailstorm/model/project'
require 'hailstorm/model/amazon_cloud'
require 'hailstorm/model/data_center'
require 'hailstorm/model/jmeter_plan'
require 'hailstorm/support/configuration'

require 'active_record/base'
require 'jmeter_plan_spec_overrides'

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

def cyclic_iterator(states_ite)
  Enumerator.new do |y|
    begin
      y << states_ite.next
    rescue StopIteration
      states_ite.rewind
      retry
    end
  end
end

def backends_stub!
  tmp_path = File.expand_path('../../../tmp', __FILE__)
  FileUtils.mkdir_p(tmp_path)

  AWS.stub!

  AWS::EC2::KeyPair.any_instance.stub(:exists?).and_return(false)
  AWS::EC2::KeyPairCollection.any_instance
                             .stub(:create)
                             .and_return(mock(AWS::EC2::KeyPair, private_key: 'foo'))
  Hailstorm::Model::AmazonCloud.any_instance
                               .stub(:identity_file_path)
                               .and_return(File.join(tmp_path, 'aws.pem'))

  security_groups = []
  AWS::EC2::SecurityGroupCollection.any_instance.stub(:filter) { security_groups }
  AWS::EC2::SecurityGroupCollection.any_instance.stub(:create) do
    mock(AWS::EC2::SecurityGroup, id: 'sg-234098').as_null_object.tap {|o| security_groups << o}
  end

  AWS::EC2::ImageCollection.any_instance.stub(:find).and_return(nil)
  mock_ami_state = cyclic_iterator([nil, :available].each)
  mock_ami = mock(AWS::EC2::Image, id: 'ami-99999').as_null_object
  mock_ami.stub!(:state) { mock_ami_state.take(1).first }
  AWS::EC2::ImageCollection.any_instance.stub(:create).and_return(mock_ami)

  mock_instance_state = cyclic_iterator([:running, :terminated].each)
  mock_ec2_instance = mock(AWS::EC2::Instance, exists?: true).as_null_object
  mock_ec2_instance.stub!(:status) { mock_instance_state.take(1).first }
  mock_ec2_instance.stub!(:terminate)
  AWS::EC2::InstanceCollection.any_instance.stub(:create).and_return(mock_ec2_instance)

  Hailstorm::Support::SSH.stub!(:ensure_connection).and_return(true)
  mock_channel = double('Mock SSH Channel').as_null_object
  mock_channel.stub!(:exec) do |&block|
    block.call(mock_channel, true)
  end
  @mock_ssh = mock(Net::SSH)
  @mock_ssh.stub!(:exec!) do |cmd, &block|
    data = case cmd
             when 'command -v java'
               '/usr/local/bin/java'
             when 'java -version'
               'java version "1.8.0.567"'
             when /jmeter -n -v/
               'Version 3.2'
             else
               cmd
           end
    if block
      block.call(double('SSH Channel'), :stdout, data)
    else
      data
    end
  end
  @mock_ssh.stub!(:open_channel) do |&block|
    block.call(mock_channel)
  end
  @mock_ssh.stub!(:find_process_id).and_return((rand * 10000).to_i)
  @mock_ssh.stub!(:process_running?).and_return(false)
  @mock_ssh.stub!(:download)
  Hailstorm::Support::SSH.stub!(:start) do |&block|
    block.call(@mock_ssh)
  end

  dc_ident_path = File.join(tmp_path, 'dc.pem')
  FileUtils.touch(dc_ident_path)
  Hailstorm::Model::DataCenter.any_instance.stub(:identity_file_path)
                              .and_return(dc_ident_path)

  Hailstorm::Model::JmeterPlan.any_instance.stub(:test_plan_file_path)
                              .and_return(@jmeter_plan.test_plan_file_path)
end

describe Hailstorm::Model::Cluster do
  before(:each) do
    @project = Hailstorm::Model::Project.where(project_code: 'cluster_spec').first_or_create!

    @jmeter_plan = Hailstorm::Model::JmeterPlan.new
    @jmeter_plan.test_plan_name = 'hailstorm-site-basic'
    @jmeter_plan.extend(JmeterPlanSpecOverrides)
    @jmeter_plan.validate_plan = true
    @jmeter_plan.active = true
    @jmeter_plan.properties = '{ "NumUsers": 10, "Duration": 180, "ServerName": "foo.com", "RampUp": 10 }'
    @jmeter_plan.project = @project
    @jmeter_plan.save!
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

        backends_stub!
        Hailstorm::Model::Cluster.configure_all(@project, config)
        expect(Hailstorm::Model::Cluster.where(project_id: @project.id).count).to eql(4)
      end
    end
  end

  context '#configure' do
    context ':amazon_cloud' do
      it 'should persist all configuration options' do
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
  end

  context '.generate_all_load' do
    it 'should generate load on all clusters' do
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

      backends_stub!
      Hailstorm::Model::Cluster.configure_all(@project, config)
      @project.build_current_execution_cycle.save!
      @project.current_execution_cycle.set_started_at(Time.now)
      Hailstorm::Model::Cluster.generate_all_load(@project)
      expect(Hailstorm::Model::LoadAgent.where('jmeter_pid IS NOT NULL').count).to be == 2
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

      backends_stub!
      Hailstorm::Model::Cluster.configure_all(@project, config)
      @project.build_current_execution_cycle.save!
      @project.current_execution_cycle.set_started_at(Time.now)
      Hailstorm::Model::Cluster.generate_all_load(@project)
      @mock_ssh.stub!(:process_running?).and_return(true)

      agents = Hailstorm::Model::Cluster.check_status(@project)
      expect(agents.size).to be == 2
    end
  end

  context '.stop_load_generation' do
    it 'should stop load generation on all clusters' do
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

      backends_stub!
      Hailstorm::Model::Cluster.configure_all(@project, config)
      @project.build_current_execution_cycle.save!
      @project.current_execution_cycle.set_started_at(Time.now)
      Hailstorm::Model::Cluster.generate_all_load(@project)

      @project.current_execution_cycle.stub!(:collect_client_stats)
      Hailstorm::Model::Cluster.stop_load_generation(@project)
      expect(Hailstorm::Model::LoadAgent.where(jmeter_pid: nil).count).to be == 2
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

      backends_stub!
      Hailstorm::Model::Cluster.configure_all(@project, config)
      expect(Hailstorm::Model::LoadAgent.count).to be > 0

      Hailstorm::Model::Cluster.terminate(@project)
      expect(Hailstorm::Model::LoadAgent.count).to be_zero
    end
  end

  context '#purge' do
    it 'should purge all clusters' do
      config = Hailstorm::Support::Configuration.new
      config.clusters(:amazon_cloud) do |aws|
        aws.access_key = 'key-1'
        aws.secret_key = 'secret-1'
        aws.region = 'us-east-1'
        aws.active = true
      end

      backends_stub!
      Hailstorm::Model::Cluster.configure_all(@project, config)

      rs1 = ActiveRecord::Base.connection.exec_query('select * from amazon_clouds limit 1')
      expect(rs1[0]['agent_ami']).to_not be_nil
      Hailstorm::Model::Cluster.first.purge
      rs2 = ActiveRecord::Base.connection.exec_query('select * from amazon_clouds limit 1')
      expect(rs2[0]['agent_ami']).to be_nil
    end
  end
end
