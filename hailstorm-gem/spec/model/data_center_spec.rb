require 'spec_helper'

require 'hailstorm/model/project'
require 'hailstorm/model/jmeter_plan'
require 'hailstorm/model/data_center'
require 'hailstorm/support/ssh'

describe Hailstorm::Model::DataCenter do

  it 'should be not be active by default' do
    expect(Hailstorm::Model::DataCenter.new).to_not be_active
  end

  it 'should not be valid without an existing ssh_identity' do
    dc = Hailstorm::Model::DataCenter.new(ssh_identity: 'hacker', active: true, machines: ['172.17.0.2'])
    dc.valid?
    expect(dc.errors).to include(:ssh_identity)
  end

  it 'should not be valid if ssh_identity file is not a regular file' do
    require 'fileutils'
    begin
      dir = '/tmp/data_center_spec_ssh_identity'
      FileUtils.mkdir_p(dir)
      reg_file = File.join(dir, 'jade.pem')
      FileUtils.touch(reg_file)
      link_file = File.join(dir, 'jade-link.pem')
      FileUtils.ln_s(reg_file, link_file) unless File.exist?(link_file)
      dc = Hailstorm::Model::DataCenter.new(ssh_identity: link_file, active: true, machines: ['172.17.0.2'])
      dc.valid?
      expect(dc.errors).to include(:ssh_identity)
    ensure
      FileUtils.rm_rf(dir)
    end
  end

  it 'should not be valid without machines' do
    attrs = { user_name: 'jack', ssh_identity: 'jack' }
    dc = Hailstorm::Model::DataCenter.new(attrs)
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
      ssh = double('ssh')
      ssh.stub!(:exec!) { '/usr/bin/java' }
      Hailstorm::Support::SSH.stub!(:start).and_yield(ssh)
      dc = Hailstorm::Model::DataCenter.new(user_name: 'jack', machines: ['172.17.0.2'], ssh_identity: 'jack')
      expect(dc.send(:java_installed?, Hailstorm::Model::MasterAgent.new)).to be_true
    end
    it 'should be false when Java is not installed' do
      ssh = double('ssh')
      ssh.stub!(:exec!) { nil }
      Hailstorm::Support::SSH.stub!(:start).and_yield(ssh)
      dc = Hailstorm::Model::DataCenter.new(user_name: 'jack', machines: ['172.17.0.2'], ssh_identity: 'jack')
      expect(dc.send(:java_installed?, Hailstorm::Model::MasterAgent.new)).to be_false
    end
  end

  context '#java_version_ok?' do
    it 'should be true if correct version of Java is installed' do
      ssh = double('ssh')
      ssh.stub!(:exec!) do
        <<-SHOUT.strip_heredoc
          java version "1.8.0_131"
          Java(TM) SE Runtime Environment (build 1.8.0_131-b11)
          Java HotSpot(TM) 64-Bit Server VM (build 25.131-b11, mixed mode)
        SHOUT
      end
      Hailstorm::Support::SSH.stub!(:start).and_yield(ssh)
      dc = Hailstorm::Model::DataCenter.new(user_name: 'jack', machines: ['172.17.0.2'], ssh_identity: 'jack')
      expect(dc.send(:java_version_ok?, Hailstorm::Model::MasterAgent.new)).to be_true
    end
    it 'should be false if version of Java is not correct' do
      ssh = double('ssh')
      ssh.stub!(:exec!) do
        <<-SHOUT.strip_heredoc
          java version "1.7.0_151"
          Java(TM) SE Runtime Environment (build 1.7.0_151-c11)
          Java HotSpot(TM) 64-Bit Server VM (build 35.151-c11, mixed mode)
        SHOUT
      end
      Hailstorm::Support::SSH.stub!(:start).and_yield(ssh)
      dc = Hailstorm::Model::DataCenter.new(user_name: 'jack', machines: ['172.17.0.2'], ssh_identity: 'jack')
      expect(dc.send(:java_version_ok?, Hailstorm::Model::MasterAgent.new)).to be_false
    end
  end

  context '#jmeter_installed?' do
    it 'should be true when JMeter is installed' do
      ssh = double('ssh')
      ssh.stub!(:exec!).and_yield(nil, :stdout, '/home/ubuntu/jmeter')
      Hailstorm::Support::SSH.stub!(:start).and_yield(ssh)
      dc = Hailstorm::Model::DataCenter.new(user_name: 'jack', machines: ['172.17.0.2'], ssh_identity: 'jack')
      expect(dc.send(:jmeter_installed?, Hailstorm::Model::MasterAgent.new)).to be_true
    end
    it 'should be false when JMeter is not installed' do
      ssh = double('ssh')
      ssh.stub!(:exec!).and_yield(nil, :stderr, 'ls: cannot access /home/darwin: No such file or directory')
      Hailstorm::Support::SSH.stub!(:start).and_yield(ssh)
      dc = Hailstorm::Model::DataCenter.new(user_name: 'jack', machines: ['172.17.0.2'], ssh_identity: 'jack')
      expect(dc.send(:jmeter_installed?, Hailstorm::Model::MasterAgent.new)).to be_false
    end
  end

  context '#jmeter_version_ok?' do
    it 'should be true if correct version of JMeter is installed' do
      ssh = double('ssh')
      ssh.stub!(:exec!) do
        <<-SHOUT.strip_heredoc
            _    ____   _    ____ _   _ _____       _ __  __ _____ _____ _____ ____     
           / \  |  _ \ / \  / ___| | | | ____|     | |  \/  | ____|_   _| ____|  _ \   
          / _ \ | |_) / _ \| |   | |_| |  _|    _  | | |\/| |  _|   | | |  _| | |_) | 
         / ___ \|  __/ ___ \ |___|  _  | |___  | |_| | |  | | |___  | | | |___|  _ <  
        /_/   \_\_| /_/   \_\____|_| |_|_____|  \___/|_|  |_|_____| |_| |_____|_| \_\ 3.2 r1790748  

        Copyright (c) 1999-2017 The Apache Software Foundation

        SHOUT
      end
      Hailstorm::Support::SSH.stub!(:start).and_yield(ssh)
      dc = Hailstorm::Model::DataCenter.new(user_name: 'jack', machines: ['172.17.0.2'], ssh_identity: 'jack')
      dc.project = Hailstorm::Model::Project.create!(project_code: 'data_center_spec_setup')
      expect(dc.send(:jmeter_version_ok?, Hailstorm::Model::MasterAgent.new)).to be_true
    end
    it 'should be false if version of JMeter is not correct' do
      ssh = double('ssh')
      ssh.stub!(:exec!) do
        <<-SHOUT.strip_heredoc
          Copyright (c) 1998-2012 The Apache Software Foundation
          Version 2.7 r1342510
        SHOUT
      end
      Hailstorm::Support::SSH.stub!(:start).and_yield(ssh)
      dc = Hailstorm::Model::DataCenter.new(user_name: 'jack', machines: ['172.17.0.2'], ssh_identity: 'jack')
      dc.project = Hailstorm::Model::Project.create!(project_code: 'data_center_spec_setup')
      expect(dc.send(:jmeter_version_ok?, Hailstorm::Model::MasterAgent.new)).to be_false
    end
  end

  context '#setup' do
    before(:each) do
      @project = Hailstorm::Model::Project.first_or_create!(project_code: 'data_center_spec_setup')
      @jmeter_plan = Hailstorm::Model::JmeterPlan.first_or_initialize(project: @project,
                                                                      test_plan_name: 'shopping_cart',
                                                                      active: true)
      @jmeter_plan.stub(:validate_plan, true)
      @jmeter_plan.stub(:calculate_content_hash) { 'ABCDE' }
      @jmeter_plan.stub(:num_threads) { 10 }
      @jmeter_plan.save!

      @machines = %w[172.17.0.2 172.17.0.3 172.17.0.4]
      @dc = Hailstorm::Model::DataCenter.new(user_name: 'root', ssh_identity: 'insecure',
                                             machines: @machines, title: 'omega-1', active: true)
      @dc.project = @project
      @dc.stub(:identity_file_exists, true)
      @dc.stub(:provision_agents, true) do
        [@jmeter_plan].collect { |jmeter_plan| @dc.send(:process_jmeter_plan, jmeter_plan) }.flatten
      end
      @dc.stub(:java_installed?, Object) { true }
      @dc.stub(:java_version_ok?, Object) { true }
      @dc.stub(:jmeter_installed?, Object) { true }
      @dc.stub(:jmeter_version_ok?, Object) { true }

      Hailstorm::Support::SSH.stub(:ensure_connection, true) { true }
    end
    context 'new machines are added' do
      it 'should create one load_agent for one machine' do
        @dc.should_receive(:java_installed?)
        @dc.should_receive(:java_version_ok?)
        @dc.should_receive(:jmeter_installed?)
        @dc.should_receive(:jmeter_version_ok?)
        Hailstorm::Support::SSH.should_receive(:ensure_connection)

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
      it 'should create one load_agent for one machine' do
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
      it 'should disable the corresponding load agent' do
        @dc.setup
        @dc.machines = %w[172.17.0.2 172.17.0.4 172.17.0.5] # removed .3 and added .5
        @dc.setup
        agent = Hailstorm::Model::MasterAgent.where(jmeter_plan_id: @jmeter_plan.id, clusterable_id: @dc.id,
                                                    clusterable_type: @dc.class.to_s,
                                                    private_ip_address: '172.17.0.3').first
        expect(agent).to_not be_active
      end
    end
    context 'without any changes' do
      it 'should not save' do
        @dc.setup
        @dc.should_not_receive(:save)
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
        @dc.should_not_receive(:provision_agents)
        @dc.setup
      end
    end
    context 'with one disabled agent' do
      before(:each) do
        @dc.setup
        @dc.load_agents.where(public_ip_address: '172.17.0.2').first.update_attributes(active: false)
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
          @dc.stub!(:connection_ok?) do |agent|
            agent.public_ip_address !~ /0\.3$/
          end
          @dc.stub!(:java_ok?) { true }
          @dc.stub!(:jmeter_ok?) { true }
          expect { @dc.setup }.to raise_error
        end
        it 'should have persisted first load agent' do
          expect(@dc.load_agents.count).to eql(1)
          expect(@dc.load_agents.where(public_ip_address: '172.17.0.2').first).to_not be_nil
        end
      end
      context 'java is not installed or version is incorrect' do
        before(:each) do
          @dc.stub!(:connection_ok?) { true }
          @dc.stub!(:java_ok?) do |agent|
            agent.public_ip_address !~ /0\.3$/
          end
          @dc.stub!(:jmeter_ok?) { true }
          expect { @dc.setup }.to raise_error
        end
        it 'should have persisted all load agents' do
          expect(@dc.load_agents.count).to eql(@machines.size)
        end
        it 'should disable the second machine' do
          expect(@dc.load_agents.where(public_ip_address: '172.17.0.3').first).to_not be_active
        end
      end
      context 'jmeter is not installed or version is not correct' do
        before(:each) do
          @dc.stub!(:connection_ok?) { true }
          @dc.stub!(:java_ok?) { true }
          @dc.stub!(:jmeter_ok?) do |agent|
            agent.public_ip_address !~ /0\.3$/
          end
          expect { @dc.setup }.to raise_error
        end
        it 'should have persisted all load agents' do
          expect(@dc.load_agents.count).to eql(@machines.size)
        end
        it 'should disable the second machine' do
          expect(@dc.load_agents.where(public_ip_address: '172.17.0.3').first).to_not be_active
        end
      end
    end
  end
end
