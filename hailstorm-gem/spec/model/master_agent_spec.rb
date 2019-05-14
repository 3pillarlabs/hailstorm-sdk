require 'spec_helper'

require 'hailstorm/model/master_agent'
require 'hailstorm/model/slave_agent'
require 'hailstorm/model/amazon_cloud'
require 'hailstorm/model/jmeter_plan'
require 'hailstorm/model/execution_cycle'

describe Hailstorm::Model::MasterAgent do
  before(:each) do
    @master_agent = Hailstorm::Model::MasterAgent.new
  end

  context 'any instance' do
    it '#master? should be true' do
      expect(@master_agent.master?).to be_true
    end
  end

  context '#start_jmeter' do
    it 'should execute command to start JMeter master' do
      clusterable = Hailstorm::Model::AmazonCloud.new
      expect(clusterable).to respond_to(:slave_agents)
      clusterable.stub_chain(:slave_agents, :where)
        .and_return([ Hailstorm::Model::SlaveAgent.new(private_ip_address: '192.168.20.100') ])
      @master_agent.stub!(:clusterable).and_return(clusterable)
      jmeter_plan = Hailstorm::Model::JmeterPlan.new
      expect(jmeter_plan).to respond_to(:master_command)
      command = '/bin/jmeter'
      jmeter_plan.stub!(:master_command).and_return(command)
      @master_agent.stub!(:jmeter_plan).and_return(jmeter_plan)
      @master_agent.stub!(:evaluate_command) { |cmd| cmd }
      @master_agent.should_receive(:execute_jmeter_command).with(command)
      @master_agent.start_jmeter
    end
  end

  context '#stop_jmeter' do
    context 'jmeter is running' do
      before(:each) do
        @master_agent.jmeter_pid = 123678
        clusterable = Hailstorm::Model::AmazonCloud.new
        clusterable.user_name = 'ubuntu'
        expect(clusterable).to respond_to(:ssh_options)
        clusterable.stub!(:ssh_options).and_return({})
        @master_agent.stub!(:clusterable).and_return(clusterable)
        @master_agent.stub!(:jmeter_plan).and_return(Hailstorm::Model::JmeterPlan.new)
        expect(@master_agent.jmeter_plan).to respond_to(:loop_forever?)
        @mock_ssh = mock(Net::SSH)
        Hailstorm::Support::SSH.stub!(:start).and_yield(@mock_ssh)
        slave_agent = Hailstorm::Model::SlaveAgent.new(private_ip_address: '192.168.20.100')
        slave_agent.stub!(:stop_jmeter)
        @master_agent.stub!(:slaves).and_return([slave_agent])
      end
      context 'jmeter_plan.loop_forever? is true' do
        it 'should terminate the remote jmeter instance' do
          @master_agent.jmeter_plan.stub!(:loop_forever?).and_return(true)
          @mock_ssh.stub!(:exec!)
          @mock_ssh.stub!(:process_running?).and_return(true)
          @mock_ssh.stub!(:terminate_process_tree)
          @master_agent.stub!(:evaluate_command)
          @master_agent.should_receive(:update_column).with(:jmeter_pid, nil)
          @master_agent.stop_jmeter(false, false, 0)
        end
      end
      context 'jmeter_plan.loop_forever? is false' do
        before(:each) do
          @master_agent.jmeter_plan.stub!(:loop_forever?).and_return(false)
        end
        context 'jmeter is not running on remote agent' do
          it 'should not terminate process, but update pid' do
            @mock_ssh.stub!(:process_running?).and_return(false)
            @master_agent.should_not_receive(:terminate_remote_jmeter)
            @master_agent.should_receive(:update_column).with(:jmeter_pid, nil)
            @master_agent.stop_jmeter(false, false, 0)
          end
        end
        context 'jmeter is running on remote agent' do
          before(:each) do
            process_states = [true, true, false].each
            @mock_ssh.stub!(:process_running?) { process_states.next }
          end
          context 'wait is true' do
            it 'should not terminate process, but update pid' do
              @master_agent.should_not_receive(:terminate_remote_jmeter)
              @master_agent.should_receive(:update_column).with(:jmeter_pid, nil)
              @master_agent.stop_jmeter(true, false, 0)
            end
          end
          context 'aborted is true' do
            it 'should terminate process and update pid' do
              @master_agent.should_receive(:terminate_remote_jmeter)
              @master_agent.should_receive(:update_column).with(:jmeter_pid, nil)
              @master_agent.stop_jmeter(false, true, 0)
            end
          end
          context 'wait is false and aborted is false' do
            it 'should raise an exception' do
              expect { @master_agent.stop_jmeter(false, false, 0) }.to raise_error(Hailstorm::Exception)
            end
          end
        end
      end
    end
    context 'jmeter is not running' do
      it 'should raise an error' do
        expect { @master_agent.stop_jmeter }.to raise_error(Hailstorm::Exception)
      end
    end
  end

  context '#result_for' do
    it 'should download and return local_file_name' do
      @master_agent.public_ip_address = '123.45.6.78'

      jmeter_plan = Hailstorm::Model::JmeterPlan.new
      jmeter_plan.project = Hailstorm::Model::Project.new(project_code: 'master_agent_spec')
      @master_agent.stub!(:jmeter_plan).and_return(jmeter_plan)
      expect(@master_agent.jmeter_plan).to respond_to(:remote_log_file)
      @master_agent.jmeter_plan.stub!(:remote_log_file).and_return('results-234-1.jtl')

      clusterable = Hailstorm::Model::AmazonCloud.new(user_name: 'ubuntu')
      expect(clusterable).to respond_to(:ssh_options)
      clusterable.stub!(:ssh_options).and_return({})
      @master_agent.stub!(:clusterable).and_return(clusterable)

      Hailstorm::Support::SSH.stub!(:start).and_yield(mock(Net::SSH).as_null_object)
      @master_agent.stub!(:gunzip_file)

      local_file_name = @master_agent.result_for(mock(Hailstorm::Model::ExecutionCycle),
                                                 RSpec.configuration.build_path)
      expect(local_file_name).to be == 'results-234-1-123_45_6_78.jtl'
    end
  end

  context '#check_status' do
    context 'jmeter_pid is not nil' do
      before(:each) do
        @master_agent.jmeter_pid = 12345
        clusterable = Hailstorm::Model::AmazonCloud.new(user_name: 'ubuntu')
        expect(clusterable).to respond_to(:ssh_options)
        clusterable.stub!(:ssh_options).and_return({})
        @master_agent.stub!(:clusterable).and_return(clusterable)
        @mock_ssh = mock(Net::SSH)
        Hailstorm::Support::SSH.stub!(:start).and_yield(@mock_ssh)
      end
      context 'JMeter is running on agent' do
        it 'should return self' do
          @mock_ssh.stub!(:process_running?).and_return(true)
          expect(@master_agent.check_status).to be == @master_agent
        end
      end
      context 'JMeter is not running on agent' do
        it 'should return nil' do
          @mock_ssh.stub!(:process_running?).and_return(false)
          expect(@master_agent.check_status).to be_nil
        end
      end
    end
    context 'jmeter_pid is nil' do
      it 'should return nil' do
        expect(@master_agent.check_status).to be_nil
      end
    end
  end
end
