# frozen_string_literal: true

require 'spec_helper'

require 'stringio'
require 'hailstorm/model/project'
require 'hailstorm/model/jmeter_plan'
require 'hailstorm/model/data_center'
require 'hailstorm/support/ssh'

describe Hailstorm::Model::DataCenter do
  def mock_hailstorm_fs
    Hailstorm.fs = instance_double(Hailstorm::Behavior::FileStore)
    allow(Hailstorm.fs).to receive(:read_identity_file).and_yield(StringIO.open('secret', 'r'))
  end

  it 'should be not be active by default' do
    expect(Hailstorm::Model::DataCenter.new).to_not be_active
  end

  it 'should not be valid without an existing ssh_identity' do
    dc = Hailstorm::Model::DataCenter.new(ssh_identity: 'hacker', active: true, machines: ['172.17.0.2'])
    dc.project = Hailstorm::Model::Project.create!(project_code: 'data_center_spec')
    allow(dc).to receive(:transfer_identity_file).and_raise(Errno::ENOENT, 'mock error')
    expect(dc).to_not be_valid
    expect(dc.errors).to include(:ssh_identity)
  end

  it 'should not be valid without machines' do
    mock_hailstorm_fs
    attrs = { user_name: 'jack', ssh_identity: 'jack' }
    dc = Hailstorm::Model::DataCenter.new(attrs)
    dc.project = Hailstorm::Model::Project.create!(project_code: 'data_center_spec')
    dc.valid?
    expect(dc.errors).to include(:machines)
  end

  context '#slug' do
    context 'with title' do
      it 'should be formatted with title' do
        dc = Hailstorm::Model::DataCenter.new(user_name: 'jack', machines: ['172.17.0.2'],
                                              ssh_identity: 'jack', title: 'Omega')
        expect(dc.slug).to eql('Data Center Omega')
      end
    end
    context 'without title' do
      it 'should not have trailing whitespace' do
        dc = Hailstorm::Model::DataCenter.new(user_name: 'jack', machines: ['172.17.0.2'], ssh_identity: 'jack')
        expect(dc.slug).to eql('Data Center')
      end
    end
  end

  context '#java_installed?' do
    it 'should be true when Java is installed' do
      ssh = instance_double(Hailstorm::Behavior::SshConnection)
      allow(ssh).to receive(:exec!) { '/usr/bin/java' }
      allow(Hailstorm::Support::SSH).to receive(:start).and_yield(ssh)
      dc = Hailstorm::Model::DataCenter.new(user_name: 'jack', machines: ['172.17.0.2'], ssh_identity: 'jack')
      dc.project = Hailstorm::Model::Project.create!(project_code: 'data_center_spec')
      expect(dc.send(:java_installed?, Hailstorm::Model::MasterAgent.new)).to be true
    end
    it 'should be false when Java is not installed' do
      ssh = instance_double(Hailstorm::Behavior::SshConnection)
      allow(ssh).to receive(:exec!) { nil }
      allow(Hailstorm::Support::SSH).to receive(:start).and_yield(ssh)
      dc = Hailstorm::Model::DataCenter.new(user_name: 'jack', machines: ['172.17.0.2'], ssh_identity: 'jack')
      dc.project = Hailstorm::Model::Project.create!(project_code: 'data_center_spec')
      expect(dc.send(:java_installed?, Hailstorm::Model::MasterAgent.new)).to be false
    end
  end

  context '#java_version_ok?' do
    it 'should be true if correct version of Java is installed' do
      ssh = instance_double(Hailstorm::Behavior::SshConnection)
      allow(ssh).to receive(:exec!) do
        <<-SHOUT.strip_heredoc
          java version "1.8.0_131"
          Java(TM) SE Runtime Environment (build 1.8.0_131-b11)
          Java HotSpot(TM) 64-Bit Server VM (build 25.131-b11, mixed mode)
        SHOUT
      end
      allow(Hailstorm::Support::SSH).to receive(:start).and_yield(ssh)
      dc = Hailstorm::Model::DataCenter.new(user_name: 'jack', machines: ['172.17.0.2'], ssh_identity: 'jack')
      dc.project = Hailstorm::Model::Project.create!(project_code: 'data_center_spec')
      expect(dc.send(:java_version_ok?, Hailstorm::Model::MasterAgent.new)).to be true
    end
    it 'should be false if version of Java is not correct' do
      ssh = instance_double(Hailstorm::Behavior::SshConnection)
      allow(ssh).to receive(:exec!) do
        <<-SHOUT.strip_heredoc
          java version "1.7.0_151"
          Java(TM) SE Runtime Environment (build 1.7.0_151-c11)
          Java HotSpot(TM) 64-Bit Server VM (build 35.151-c11, mixed mode)
        SHOUT
      end
      allow(Hailstorm::Support::SSH).to receive(:start).and_yield(ssh)
      dc = Hailstorm::Model::DataCenter.new(user_name: 'jack', machines: ['172.17.0.2'], ssh_identity: 'jack')
      dc.project = Hailstorm::Model::Project.create!(project_code: 'data_center_spec')
      expect(dc.send(:java_version_ok?, Hailstorm::Model::MasterAgent.new)).to be false
    end
  end

  context '#jmeter_installed?' do
    it 'should be true when JMeter is installed' do
      ssh = instance_double(Hailstorm::Behavior::SshConnection)
      allow(ssh).to receive(:exec!).and_yield(nil, :stdout, '/home/ubuntu/jmeter')
      allow(Hailstorm::Support::SSH).to receive(:start).and_yield(ssh)
      dc = Hailstorm::Model::DataCenter.new(user_name: 'jack', machines: ['172.17.0.2'], ssh_identity: 'jack')
      dc.project = Hailstorm::Model::Project.create!(project_code: 'data_center_spec')
      expect(dc.send(:jmeter_installed?, Hailstorm::Model::MasterAgent.new)).to be true
    end
    it 'should be false when JMeter is not installed' do
      ssh = instance_double(Hailstorm::Behavior::SshConnection)
      allow(ssh).to receive(:exec!).and_yield(nil, :stderr, 'ls: cannot access /home/darwin: No such file or directory')
      allow(Hailstorm::Support::SSH).to receive(:start).and_yield(ssh)
      dc = Hailstorm::Model::DataCenter.new(user_name: 'jack', machines: ['172.17.0.2'], ssh_identity: 'jack')
      dc.project = Hailstorm::Model::Project.create!(project_code: 'data_center_spec')
      expect(dc.send(:jmeter_installed?, Hailstorm::Model::MasterAgent.new)).to be false
    end
  end

  context '#jmeter_version_ok?' do
    it 'should be true if correct version of JMeter is installed' do
      ssh = instance_double(Hailstorm::Behavior::SshConnection)
      allow(ssh).to receive(:exec!) do
        <<-SHOUT.strip_heredoc
            _    ____   _    ____ _   _ _____       _ __  __ _____ _____ _____ ____
           / \  |  _ \ / \  / ___| | | | ____|     | |  \/  | ____|_   _| ____|  _ \
          / _ \ | |_) / _ \| |   | |_| |  _|    _  | | |\/| |  _|   | | |  _| | |_) |
         / ___ \|  __/ ___ \ |___|  _  | |___  | |_| | |  | | |___  | | | |___|  _ <
        /_/   \_\_| /_/   \_\____|_| |_|_____|  \___/|_|  |_|_____| |_| |_____|_| \_\ 5.2.1

        Copyright (c) 1999-2019 The Apache Software Foundation

        SHOUT
      end
      allow(Hailstorm::Support::SSH).to receive(:start).and_yield(ssh)
      dc = Hailstorm::Model::DataCenter.new(user_name: 'jack', machines: ['172.17.0.2'], ssh_identity: 'jack')
      dc.project = Hailstorm::Model::Project.create!(project_code: 'data_center_spec_setup')
      expect(dc.send(:jmeter_version_ok?, Hailstorm::Model::MasterAgent.new)).to be true
    end
    it 'should be false if version of JMeter is not correct' do
      ssh = instance_double(Hailstorm::Behavior::SshConnection)
      allow(ssh).to receive(:exec!) do
        <<-SHOUT.strip_heredoc
          Copyright (c) 1998-2012 The Apache Software Foundation
          Version 2.7 r1342510
        SHOUT
      end
      allow(Hailstorm::Support::SSH).to receive(:start).and_yield(ssh)
      dc = Hailstorm::Model::DataCenter.new(user_name: 'jack', machines: ['172.17.0.2'], ssh_identity: 'jack')
      dc.project = Hailstorm::Model::Project.create!(project_code: 'data_center_spec_setup')
      expect(dc.send(:jmeter_version_ok?, Hailstorm::Model::MasterAgent.new)).to be false
    end
  end

  context '#ssh_options' do
    context 'standard SSH port' do
      before(:each) do
        @dc = Hailstorm::Model::DataCenter.new(user_name: 'jack', machines: ['172.17.0.2'], ssh_identity: 'jack')
        @dc.project = Hailstorm::Model::Project.create!(project_code: 'data_center_spec')
      end
      it 'should have :keys' do
        expect(@dc.ssh_options).to include(:keys)
      end
      it 'should not have :port' do
        expect(@dc.ssh_options).to_not include(:port)
      end
    end
    context 'non standard SSH port' do
      before(:each) do
        @dc = Hailstorm::Model::DataCenter.new(user_name: 'jack', machines: ['172.17.0.2'], ssh_identity: 'jack',
                                               ssh_port: 8022)
        @dc.project = Hailstorm::Model::Project.create!(project_code: 'data_center_spec')
      end
      it 'should have :keys' do
        expect(@dc.ssh_options).to include(:keys)
      end
      it 'should have :port' do
        expect(@dc.ssh_options).to include(:port)
        expect(@dc.ssh_options[:port]).to eql(8022)
      end
    end
  end

  context '#setup' do
    before(:each) do
      @project = Hailstorm::Model::Project.first_or_create!(project_code: 'data_center_spec_setup')
      @jmeter_plan = Hailstorm::Model::JmeterPlan.first_or_initialize(project: @project,
                                                                      test_plan_name: 'shopping_cart',
                                                                      active: true)
      allow(@jmeter_plan).to receive(:validate_plan).and_return(true)
      allow(@jmeter_plan).to receive(:calculate_content_hash).and_return('ABCDE')
      allow(@jmeter_plan).to receive(:num_threads).and_return(10)
      @jmeter_plan.save!

      @machines = %w[172.17.0.2 172.17.0.3 172.17.0.4]
      @dc = Hailstorm::Model::DataCenter.new(user_name: 'root', ssh_identity: 'insecure',
                                             machines: @machines, title: 'omega-1', active: true)
      @dc.project = @project
      allow(@dc).to receive(:provision_agents) do
        [@jmeter_plan].collect { |jmeter_plan| @dc.send(:process_jmeter_plan, jmeter_plan) }.flatten
      end
      allow(@dc).to receive(:java_installed?).and_return(true)
      allow(@dc).to receive(:java_version_ok?).and_return(true)
      allow(@dc).to receive(:jmeter_installed?).and_return(true)
      allow(@dc).to receive(:jmeter_version_ok?).and_return(true)

      allow(Hailstorm::Support::SSH).to receive(:ensure_connection).and_return(true)

      mock_hailstorm_fs
    end
    context 'new machines are added' do
      it 'should create one load_agent for one machine' do
        expect(@dc).to receive(:java_installed?)
        expect(@dc).to receive(:java_version_ok?)
        expect(@dc).to receive(:jmeter_installed?)
        expect(@dc).to receive(:jmeter_version_ok?)
        expect(Hailstorm::Support::SSH).to receive(:ensure_connection)

        @dc.setup
        @machines.each do |machine|
          agent = Hailstorm::Model::MasterAgent.where(jmeter_plan_id: @jmeter_plan.id, clusterable_id: @dc.id,
                                                      clusterable_type: @dc.class.to_s,
                                                      private_ip_address: machine).all.first
          expect(agent).to_not be_nil
          expect(agent.public_ip_address).to eql(machine)
          expect(agent.identifier).to eql(machine)
        end
      end
    end
    context 'machines are removed' do
      it 'should disable the corresponding load agent' do
        @dc.setup
        @dc.machines = ['172.17.0.2']
        @dc.setup
        agent = Hailstorm::Model::MasterAgent.where(jmeter_plan_id: @jmeter_plan.id, clusterable_id: @dc.id,
                                                    clusterable_type: @dc.class.to_s,
                                                    private_ip_address: '172.17.0.2').first
        expect(agent).to be_active
        %w[172.17.0.3 172.17.0.4].each do |machine|
          agent = Hailstorm::Model::MasterAgent.where(jmeter_plan_id: @jmeter_plan.id, clusterable_id: @dc.id,
                                                      clusterable_type: @dc.class.to_s,
                                                      private_ip_address: machine).first
          expect(agent).to_not be_active
        end
      end
    end
    context 'machines are changed' do
      it 'should create one load_agent for ones added' do
        @dc.setup
        @dc.machines = %w[172.17.0.2 172.17.0.4 172.17.0.5] # removed .3 and added .5
        @dc.setup
        %w[172.17.0.2 172.17.0.4 172.17.0.5].each do |machine|
          agent = Hailstorm::Model::MasterAgent.where(jmeter_plan_id: @jmeter_plan.id, clusterable_id: @dc.id,
                                                      clusterable_type: @dc.class.to_s,
                                                      private_ip_address: machine).first
          expect(agent).to be_active
        end
      end
      it 'should disable the agents for machines removed' do
        @dc.setup
        @dc.machines = %w[172.17.0.2 172.17.0.4 172.17.0.5] # removed .3 and added .5
        @dc.setup
        agent = Hailstorm::Model::MasterAgent.where(jmeter_plan_id: @jmeter_plan.id, clusterable_id: @dc.id,
                                                    clusterable_type: @dc.class.to_s,
                                                    private_ip_address: '172.17.0.3').first
        expect(agent).to_not be_active
      end
      it 'should not persist a load agent if setup fails' do
        @dc.setup
        @dc.machines = %w[172.17.0.2 172.17.0.4 172.17.0.5] # removed .3 and added .5
        allow(@dc).to receive(:connection_ok?) do |agent|
          agent.public_ip_address !~ /0\.5$/
        end
        @dc.setup
        agent = Hailstorm::Model::MasterAgent.where(jmeter_plan_id: @jmeter_plan.id, clusterable_id: @dc.id,
                                                    clusterable_type: @dc.class.to_s,
                                                    private_ip_address: '172.17.0.5').first
        expect(agent).to be_nil
      end
    end
    context 'without any changes' do
      it 'should not save' do
        @dc.setup
        expect(@dc).to_not receive(:save)
        @dc.setup
      end
    end
    context 'not active' do
      it 'should persist the data center attributes' do
        @dc.active = false
        @dc.setup
        expect(Hailstorm::Model::DataCenter.where(title: 'omega-1').first).to_not be_nil
      end
      it 'should not provision agents' do
        @dc.active = false
        expect(@dc).to_not receive(:provision_agents)
        @dc.setup
      end
    end
    context 'with one disabled agent' do
      before(:each) do
        @dc.setup
        @dc.load_agents.where(public_ip_address: '172.17.0.2').first.update(active: false)
        @dc.setup
      end
      it 'should enable the agent' do
        expect(@dc.load_agents.where(public_ip_address: '172.17.0.2').first).to be_active
      end
      it 'should not create a new agent' do
        expect(@dc.load_agents.count).to eql(@machines.size)
      end
    end
    context 'for second machine, fails because' do
      context 'it is not reachable' do
        before(:each) do
          allow(@dc).to receive(:connection_ok?) do |agent|
            agent.public_ip_address !~ /0\.3$/
          end
          allow(@dc).to receive(:java_ok?).and_return(true)
          allow(@dc).to receive(:jmeter_ok?).and_return(true)
          @dc.setup
        end
        it 'should have persisted other load agents' do
          expect(@dc.load_agents.count).to eql(@machines.size - 1)
        end
        it 'should not persist the instance with failed checks' do
          expect(@dc.load_agents.where(public_ip_address: '172.17.0.3').first).to be_nil
        end
        it 'should raise Hailstorm::DataCenterAccessFailure' do
          allow(@dc).to receive(:connection_ok?).and_return(false)
          master_agent = Hailstorm::Model::MasterAgent.new(private_ip_address: '172.17.0.2')
          allow(master_agent).to receive(:persisted?).and_return(true)
          expect(master_agent).to receive(:update_attribute).with(:active, false)
          expect { @dc.send(:agent_before_save_on_create, master_agent) }
            .to raise_error(Hailstorm::DataCenterAccessFailure) { |error| expect(error.diagnostics).to_not be_blank }
        end
      end
      context 'java is not installed or version is incorrect' do
        before(:each) do
          allow(@dc).to receive(:connection_ok?) { true }
          allow(@dc).to receive(:java_ok?) do |agent|
            agent.public_ip_address !~ /0\.3$/
          end
          allow(@dc).to receive(:jmeter_ok?).and_return(true)
          @dc.setup
        end
        it 'should have persisted other load agents' do
          expect(@dc.load_agents.count).to eql(@machines.size - 1)
        end
        it 'should not persist the instance with failed checks' do
          expect(@dc.load_agents.where(public_ip_address: '172.17.0.3').first).to be_nil
        end
        it 'should raise Hailstorm::DataCenterJavaFailure' do
          allow(@dc).to receive(:java_ok?).and_return(false)
          master_agent = Hailstorm::Model::MasterAgent.new(private_ip_address: '172.17.0.2')
          expect { @dc.send(:agent_before_save_on_create, master_agent) }
            .to raise_error(Hailstorm::DataCenterJavaFailure) { |error| expect(error.diagnostics).to_not be_blank }
        end
      end
      context 'jmeter is not installed or version is not correct' do
        before(:each) do
          allow(@dc).to receive(:connection_ok?).and_return(true)
          allow(@dc).to receive(:java_ok?).and_return(true)
          allow(@dc).to receive(:jmeter_ok?) do |agent|
            agent.public_ip_address !~ /0\.3$/
          end
          @dc.setup
        end
        it 'should have persisted other load agents' do
          expect(@dc.load_agents.count).to eql(@machines.size - 1)
        end
        it 'should not persist the instance with failed checks' do
          expect(@dc.load_agents.where(public_ip_address: '172.17.0.3').first).to be_nil
        end
        it 'should raise Hailstorm::DataCenterJMeterFailure' do
          allow(@dc).to receive(:jmeter_ok?).and_return(false)
          master_agent = Hailstorm::Model::MasterAgent.new(private_ip_address: '172.17.0.2')
          expect { @dc.send(:agent_before_save_on_create, master_agent) }
            .to raise_error(Hailstorm::DataCenterJMeterFailure) { |error| expect(error.diagnostics).to_not be_blank }
        end
      end
    end
  end

  context '#purge' do
    it 'should not raise error' do
      dc = Hailstorm::Model::DataCenter.new(user_name: 'root', ssh_identity: 'insecure',
                                            machines: ['10.0.10.10'], title: 'omega-1', active: true)
      expect { dc.purge }.to_not raise_error
    end
  end
end
