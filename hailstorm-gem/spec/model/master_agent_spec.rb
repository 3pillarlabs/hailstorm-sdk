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
      expect(@master_agent.master?).to be true
    end
  end

  context '#start_jmeter' do
    it 'should execute command to start JMeter master' do
      clusterable = Hailstorm::Model::AmazonCloud.new
      expect(clusterable).to respond_to(:slave_agents)
      agents = [Hailstorm::Model::SlaveAgent.new(private_ip_address: '192.168.20.100')]
      allow(clusterable).to receive_message_chain(:slave_agents, :where).and_return(agents)
      allow(@master_agent).to receive(:clusterable).and_return(clusterable)
      jmeter_plan = Hailstorm::Model::JmeterPlan.new
      expect(jmeter_plan).to respond_to(:master_command)
      command = '/bin/jmeter'
      allow(jmeter_plan).to receive(:master_command).and_return(command)
      allow(@master_agent).to receive(:jmeter_plan).and_return(jmeter_plan)
      allow(@master_agent).to receive(:evaluate_command) { |cmd| cmd }
      expect(@master_agent).to receive(:execute_jmeter_command).with(command)
      @master_agent.start_jmeter
    end
  end

  context '#stop_jmeter' do
    context 'jmeter is running' do
      before(:each) do
        @master_agent.jmeter_pid = 123678
        clusterable = Hailstorm::Model::AmazonCloud.new
        clusterable.user_name = 'ubuntu'
        allow(clusterable).to receive(:ssh_options).and_return({})
        allow(@master_agent).to receive(:clusterable).and_return(clusterable)
        allow(@master_agent).to receive(:jmeter_plan).and_return(Hailstorm::Model::JmeterPlan.new)
        slave_agent = Hailstorm::Model::SlaveAgent.new(private_ip_address: '192.168.20.100')
        allow(slave_agent).to receive(:stop_jmeter)
        allow(@master_agent).to receive(:slaves).and_return([slave_agent])
        @mock_ssh = instance_double(Hailstorm::Behavior::SshConnection)
        allow(Hailstorm::Support::SSH).to receive(:start).and_yield(@mock_ssh)
      end

      context 'jmeter_plan.loop_forever? is true' do
        it 'should terminate the remote jmeter instance' do
          allow(@master_agent.jmeter_plan).to receive(:loop_forever?).and_return(true)
          allow(@mock_ssh).to receive(:exec!)
          allow(@mock_ssh).to receive(:process_running?).and_return(true)
          allow(@mock_ssh).to receive(:terminate_process_tree)
          allow(@master_agent).to receive(:evaluate_command)
          expect(@master_agent).to receive(:update_column).with(:jmeter_pid, nil)
          @master_agent.stop_jmeter(false, false, 0)
        end
      end
      context 'jmeter_plan.loop_forever? is false' do
        before(:each) do
          allow(@master_agent.jmeter_plan).to receive(:loop_forever?).and_return(false)
        end
        context 'jmeter is not running on remote agent' do
          it 'should not terminate process, but update pid' do
            allow(@mock_ssh).to receive(:process_running?).and_return(false)
            expect(@master_agent).to_not receive(:terminate_remote_jmeter)
            expect(@master_agent).to receive(:update_column).with(:jmeter_pid, nil)
            @master_agent.stop_jmeter(false, false, 0)
          end
        end
        context 'jmeter is running on remote agent' do
          before(:each) do
            process_states = [true, true, false].each
            allow(@mock_ssh).to receive(:process_running?) { process_states.next }
          end
          context 'wait is true' do
            it 'should not terminate process, but update pid' do
              expect(@master_agent).to_not receive(:terminate_remote_jmeter)
              expect(@master_agent).to receive(:update_column).with(:jmeter_pid, nil)
              @master_agent.stop_jmeter(true, false, 0)
            end
          end
          context 'aborted is true' do
            it 'should terminate process and update pid' do
              expect(@master_agent).to receive(:terminate_remote_jmeter)
              expect(@master_agent).to receive(:update_column).with(:jmeter_pid, nil)
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
      allow(@master_agent).to receive(:jmeter_plan).and_return(jmeter_plan)
      allow(@master_agent.jmeter_plan).to receive(:remote_log_file).and_return('results-234-1.jtl')

      clusterable = Hailstorm::Model::AmazonCloud.new(user_name: 'ubuntu')
      allow(clusterable).to receive(:ssh_options).and_return({})
      allow(@master_agent).to receive(:clusterable).and_return(clusterable)

      mock_ssh = spy('Net::SSH::Connection::Session')
      allow(Hailstorm::Support::SSH).to receive(:start).and_yield(mock_ssh)
      allow(@master_agent).to receive(:gunzip_file)

      local_file_name = @master_agent.result_for(instance_double(Hailstorm::Model::ExecutionCycle),
                                                 RSpec.configuration.build_path)
      expect(local_file_name).to be == 'results-234-1-123_45_6_78.jtl'
    end
  end

  context '#check_status' do
    context 'jmeter_pid is not nil' do
      before(:each) do
        @master_agent.jmeter_pid = 12345
        clusterable = Hailstorm::Model::AmazonCloud.new(user_name: 'ubuntu')
        allow(clusterable).to receive(:ssh_options).and_return({})
        allow(@master_agent).to receive(:clusterable).and_return(clusterable)
        @mock_ssh = instance_double(Hailstorm::Behavior::SshConnection)
        allow(Hailstorm::Support::SSH).to receive(:start).and_yield(@mock_ssh)
      end

      context 'JMeter is running on agent' do
        it 'should return self' do
          allow(@mock_ssh).to receive(:process_running?).and_return(true)
          expect(@master_agent.check_status).to be == @master_agent
        end
      end

      context 'JMeter is not running on agent' do
        it 'should return nil' do
          allow(@mock_ssh).to receive(:process_running?).and_return(false)
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
