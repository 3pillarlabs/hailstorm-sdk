require 'spec_helper'
require 'hailstorm/model/load_agent'
require 'hailstorm/model/jmeter_plan'
require 'hailstorm/model/amazon_cloud'
require 'hailstorm/model/project'

describe Hailstorm::Model::LoadAgent do

  before(:each) do
    @load_agent = Hailstorm::Model::LoadAgent.new
  end

  context 'new instance' do
    it '#first_use? should be true' do
      expect(@load_agent.first_use?).to be true
    end
    it '#jmeter_running? should be false' do
      expect(@load_agent.jmeter_running?).to be false
    end
    it '#running? should be false' do
      expect(@load_agent.running?).to be false
    end
  end

  context '#upload_scripts' do
    context '#script_upload_needed? is false' do
      it 'should do nothing' do
        allow(@load_agent).to receive(:script_upload_needed?).and_return(false)
        expect(Hailstorm::Support::SSH).to_not receive(:start)
        @load_agent.upload_scripts
      end
    end
    context '#script_upload_needed? is true' do
      before(:each) do
        jmeter_plan = Hailstorm::Model::JmeterPlan.new
        jmeter_plan.test_plan_name = 'spec'
        allow(@load_agent).to receive(:jmeter_plan).and_return(jmeter_plan)
      end

      it 'should sync the local app hierarchy with remote' do
        project_code = 'load_agent_spec'
        clusterable = Hailstorm::Model::AmazonCloud.new(user_name: 'ubuntu')
        clusterable.project = Hailstorm::Model::Project.new(project_code: project_code)
        expect(clusterable).to respond_to(:ssh_options)
        allow(clusterable).to receive(:ssh_options).and_return({})
        allow(@load_agent).to receive(:clusterable).and_return(clusterable)

        expect(@load_agent.jmeter_plan).to respond_to(:remote_directory_hierarchy)
        hierarchy = { project_code => { log: nil, jmeter: { store: { admin: nil } } }.deep_stringify_keys }
        allow(@load_agent.jmeter_plan).to receive(:remote_directory_hierarchy).and_return(hierarchy)

        mock_ssh = instance_double(Hailstorm::Behavior::SshConnection)
        allow(Hailstorm::Support::SSH).to receive(:start).and_yield(mock_ssh)
        dir_paths = []
        allow(mock_ssh).to receive(:make_directory) { |dp| dir_paths << dp }
        expect(mock_ssh).to receive(:make_directory).exactly(5).times

        root_path = Hailstorm.workspace(project_code).app_path
        expect(@load_agent.jmeter_plan).to respond_to(:test_artifacts)
        artifacts = ["#{File.join(root_path, 'store', 'prime.jmx')}",
                     "#{File.join(root_path, 'store', 'admin', 'prime.jmx')}"]
        allow(@load_agent.jmeter_plan).to receive(:test_artifacts).and_return(artifacts)
        allow(mock_ssh).to receive(:upload) { |local, remote| dir_paths.push([local, remote]) }
        expect(mock_ssh).to receive(:upload).exactly(2).times

        @load_agent.upload_scripts

        expect(dir_paths).to include("/home/ubuntu/#{project_code}")
        expect(dir_paths).to include("/home/ubuntu/#{project_code}/log")
        expect(dir_paths).to include("/home/ubuntu/#{project_code}/jmeter/store")
        expect(dir_paths).to include("/home/ubuntu/#{project_code}/jmeter/store/admin")
        expect(dir_paths).to include([
          @load_agent.jmeter_plan.test_artifacts[0],
          "/home/ubuntu/#{project_code}/jmeter/store/prime.jmx"
        ])
        expect(dir_paths).to include([
          @load_agent.jmeter_plan.test_artifacts[1],
          "/home/ubuntu/#{project_code}/jmeter/store/admin/prime.jmx"
        ])
      end

      it 'should set first_use to false' do
        allow(@load_agent).to receive(:ssh_start_args).and_return(['23.32.34.45', 'ubuntu', {}])
        allow(Hailstorm::Support::SSH).to receive(:start).and_yield(instance_double(Hailstorm::Behavior::SshConnection))
        allow(@load_agent).to receive(:remote_sync)
        @load_agent.upload_scripts
        expect(@load_agent.first_use?).to be false
      end
    end
  end

  context '#evaluate_command' do
    it 'should compile the template' do
      clusterable = Hailstorm::Model::AmazonCloud.new(user_name: 'ubuntu')
      allow(@load_agent).to receive(:clusterable).and_return(clusterable)
      outputs = @load_agent.send(:evaluate_command, '<%= @user_home %>,<%= @jmeter_home %>').split(',')
      expect(outputs[0]).to be == @load_agent.clusterable.user_home
      expect(outputs[1]).to be == @load_agent.clusterable.jmeter_home
    end
  end

  context '#execute_jmeter_command' do
    before(:each) do
      @load_agent.jmeter_plan = Hailstorm::Model::JmeterPlan.new
      allow(@load_agent).to receive(:ssh_start_args).and_return(['23.32.34.45', 'ubuntu', {}])
      @mock_ssh = instance_double(Hailstorm::Behavior::SshConnection)
      allow(Hailstorm::Support::SSH).to receive(:start).and_yield(@mock_ssh)
      allow(@mock_ssh).to receive(:exec!)
    end

    it 'should update jmeter_pid on success' do
      allow(@mock_ssh).to receive(:find_process_id).and_return(999)
      expect(@load_agent).to receive(:update_column).with(:jmeter_pid, 999)
      @load_agent.send(:execute_jmeter_command, 'ls')
    end

    it 'should raise error if jmeter_pid is nil' do
      allow(@load_agent).to receive(:identifier).and_return('i-1234456678')
      allow(@load_agent).to receive(:public_ip_address).and_return('123.45.67.89')
      allow(@mock_ssh).to receive(:find_process_id).and_return(nil)
      expect { @load_agent.send(:execute_jmeter_command, 'ls') }.to raise_error(Hailstorm::Exception)
    end
  end
end
