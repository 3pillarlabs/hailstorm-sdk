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
      expect(@load_agent.first_use?).to be_true
    end
    it '#jmeter_running? should be false' do
      expect(@load_agent.jmeter_running?).to be_false
    end
    it '#running? should be false' do
      expect(@load_agent.running?).to be_false
    end
  end
  
  context '#upload_scripts' do
    context '#script_upload_needed? is false' do
      it 'should do nothing' do
        @load_agent.stub!(:script_upload_needed?).and_return(false)
        Hailstorm::Support::SSH.should_not_receive(:start)
        @load_agent.upload_scripts
      end
    end
    context '#script_upload_needed? is true' do
      before(:each) do
        jmeter_plan = Hailstorm::Model::JmeterPlan.new
        jmeter_plan.test_plan_name = 'spec'
        @load_agent.stub!(:jmeter_plan).and_return(jmeter_plan)
      end

      it 'should sync the local app hierarchy with remote' do
        project_code = 'load_agent_spec'
        clusterable = Hailstorm::Model::AmazonCloud.new(user_name: 'ubuntu')
        clusterable.project = Hailstorm::Model::Project.new(project_code: project_code)
        expect(clusterable).to respond_to(:ssh_options)
        clusterable.stub!(:ssh_options).and_return({})
        @load_agent.stub!(:clusterable).and_return(clusterable)

        expect(@load_agent.jmeter_plan).to respond_to(:remote_directory_hierarchy)
        @load_agent
          .jmeter_plan
          .stub!(:remote_directory_hierarchy)
          .and_return({ project_code => { log: nil, jmeter: { store: { admin: nil } } }.deep_stringify_keys })

        mock_ssh = mock(Net::SSH)
        Hailstorm::Support::SSH.stub!(:start).and_yield(mock_ssh)
        dir_paths = []
        mock_ssh.stub!(:make_directory) { |dp| dir_paths << dp }
        mock_ssh.should_receive(:make_directory).exactly(5).times

        root_path = Hailstorm.workspace(project_code).app_path
        expect(@load_agent.jmeter_plan).to respond_to(:test_artifacts)
        @load_agent.jmeter_plan
          .stub!(:test_artifacts)
          .and_return([
            "#{File.join(root_path, 'store', 'prime.jmx')}",
            "#{File.join(root_path, 'store', 'admin', 'prime.jmx')}"
          ])
        mock_ssh.stub!(:upload) { |local, remote| dir_paths.push([local, remote]) }
        mock_ssh.should_receive(:upload).exactly(2).times

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
        @load_agent.stub!(:ssh_start_args).and_return([])
        Hailstorm::Support::SSH.stub!(:start).and_yield(mock(Net::SSH))
        @load_agent.stub!(:remote_sync)
        @load_agent.upload_scripts
        expect(@load_agent.first_use?).to be_false
      end
    end
  end

  context '#evaluate_command' do
    it 'should compile the template' do
      clusterable = Hailstorm::Model::AmazonCloud.new(user_name: 'ubuntu')
      @load_agent.stub!(:clusterable).and_return(clusterable)
      outputs = @load_agent.send(:evaluate_command, '<%= @user_home %>,<%= @jmeter_home %>').split(',')
      expect(outputs[0]).to be == @load_agent.clusterable.user_home
      expect(outputs[1]).to be == @load_agent.clusterable.jmeter_home
    end
  end

  context '#execute_jmeter_command' do
    before(:each) do
      @load_agent.jmeter_plan = Hailstorm::Model::JmeterPlan.new
      @load_agent.stub!(:ssh_start_args).and_return([])
      @mock_ssh = mock(Net::SSH)
      Hailstorm::Support::SSH.stub!(:start).and_yield(@mock_ssh)
      @mock_ssh.stub!(:exec!)
    end
    it 'should update jmeter_pid on success' do
      @mock_ssh.stub!(:find_process_id).and_return(999)
      @load_agent.should_receive(:update_column).with(:jmeter_pid, 999)
      @load_agent.send(:execute_jmeter_command, 'ls')
    end
    it 'should raise error if jmeter_pid is nil' do
      @load_agent.stub!(:identifier).and_return('i-1234456678')
      @load_agent.stub!(:public_ip_address).and_return('123.45.67.89')
      @mock_ssh.stub!(:find_process_id).and_return(nil)
      expect { @load_agent.send(:execute_jmeter_command, 'ls') }.to raise_error(Hailstorm::Exception)
    end
  end
end
