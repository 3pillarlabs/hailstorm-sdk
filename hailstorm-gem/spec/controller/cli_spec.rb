require 'spec_helper'

require 'active_record/base'
require 'hailstorm/exceptions'
require 'hailstorm/controller/cli'
require 'hailstorm/model/project'
require 'hailstorm/model/nmon'
require 'hailstorm/cli/help_doc'

describe Hailstorm::Controller::Cli do
  before(:each) do
    @middleware = Hailstorm.application
    @app = Hailstorm::Controller::Cli.new(@middleware)
    @app.stub!(:saved_history_path).and_return(File.join(java.lang.System.getProperty('user.home'),
                                                         '.spec_hailstorm_history'))
    ActiveRecord::Base.stub!(:clear_all_connections!)
  end

  context '#process_commands' do
    context 'nil command' do
      context 'exit_ok? == true' do
        it 'should set @exit_command_counter < 0' do
          expect(@app.exit_command_counter).to be == 0
          Readline.stub!(:readline).and_return(nil)
          @app.stub!(:exit_ok?).and_return(true)
          @app.process_commands
          expect(@app.exit_command_counter).to be < 0
        end
      end
    end
    it 'should skip empty lines' do
      @app.should_not_receive(:save_history)
      cmds_ite = ['', nil].each
      Readline.stub!(:readline) { |_p, _h| cmds_ite.next }
      @app.process_commands
    end
    it 'should try interpret a command' do
      @app.should_receive(:save_history).with('help')
      cmds_ite = ['help', nil].each
      Readline.stub!(:readline) { |_p, _h| cmds_ite.next }
      @app.process_commands
    end
    context '\'start\' command' do
      it 'should modify the readline prompt' do
        @app.stub!(:start)
        cmds_ite = ['start', nil].each_with_index
        Readline.stub!(:readline) do |_p, _h|
          cmd, idx = cmds_ite.next
          expect(_p).to match(/\*\s+$/) if idx > 0
          cmd
        end
        @app.process_commands
      end
    end
    context '\'stop\', \'abort\' command' do
      it 'should modify the readline prompt' do
        @app.stub!(:stop)
        @app.stub!(:abort)
        cmds_ite = ['stop', 'abort', nil].each_with_index
        Readline.stub!(:readline) do |_p, _h|
          cmd, idx = cmds_ite.next
          expect(_p).to_not match(/\*\s+$/) if idx > 0
          cmd
        end
        @app.process_commands
      end
    end
    it 'should rescue IncorrectCommandException' do
      @app.should_receive(:save_history).with('help coffee')
      cmds_ite = ['help coffee', nil].each
      Readline.stub!(:readline) { |_p, _h| cmds_ite.next }
      @app.process_commands
    end
    context 'rescue UnknownCommandException' do
      context 'Hailstorm.is_production? == false' do
        before(:each) do
          Hailstorm.stub!(:is_production?).and_return(false)
        end
        it 'should evaluate command as Ruby' do
          cmds = ['puts "Hello, World"', '1 + 2', 'hello', nil]
          cmds_ite = cmds.each
          Readline.stub!(:readline) { |_p, _h| cmds_ite.next }
          @app.should_receive(:save_history).exactly(cmds.length - 1).times
          @app.process_commands
        end
        it 'should rescue evaluation exception/error' do
          @app.should_receive(:save_history).with('puts "Hello, World')
          cmds_ite = ['puts "Hello, World', nil].each
          Readline.stub!(:readline) { |_p, _h| cmds_ite.next }
          @app.process_commands
        end
      end
      context 'Hailstorm.env == production' do
        it 'should save the commands in history' do
          Hailstorm.stub!(:is_production?).and_return(true)
          cmds = ['puts "Hello, World"', nil]
          cmds_ite = cmds.each
          Readline.stub!(:readline) {|_p, _h| cmds_ite.next}
          @app.should_receive(:save_history).once
          @app.process_commands
        end
      end
    end
    it 'should rescue Hailstorm::ThreadJoinException' do
      @app.should_receive(:save_history).with('start redeploy')
      @app.stub!(:start).and_raise(Hailstorm::ThreadJoinException.new(nil))
      cmds_ite = ['start redeploy', nil].each
      Readline.stub!(:readline) { |_p, _h| cmds_ite.next }
      @app.process_commands
    end
    it 'should rescue Hailstorm::Exception' do
      @app.should_receive(:save_history).with('results')
      @app.stub!(:interpret_command).and_raise(Hailstorm::Exception)
      cmds_ite = ['results', nil].each
      Readline.stub!(:readline) { |_p, _h| cmds_ite.next }
      @app.process_commands
    end
    it 'should rescue StandardError' do
      @app.should_receive(:save_history).with('setup')
      @app.stub!(:interpret_command).and_raise(StandardError)
      cmds_ite = ['setup', nil].each
      Readline.stub!(:readline) { |_p, _h| cmds_ite.next }
      @app.process_commands
    end
  end

  context '#process_cmd_line' do
    [:quit, :exit].each do | cmd |
      context 'exit_ok? == true' do
        context "'#{cmd}' command" do
          it 'should set @exit_command_counter < 0' do
            expect(@app.exit_command_counter).to be == 0
            @app.stub!(:exit_ok?).and_return(true)
            @app.process_cmd_line(cmd.to_s)
            expect(@app.exit_command_counter).to be < 0
          end
        end
      end
      context 'exit_ok? == false' do
        before(:each) do
          @app.stub!(:exit_ok?).and_return(false)
        end
        context "'#{cmd}' command" do
          it 'once should increment @exit_command_counter' do
            expect(@app.exit_command_counter).to be == 0
            @app.process_cmd_line(cmd.to_s)
            expect(@app.exit_command_counter).to be > 0
          end
          it 'twice should set @exit_command_counter < 0' do
            expect(@app.exit_command_counter).to be == 0
            @app.process_cmd_line(cmd.to_s)
            @app.process_cmd_line(cmd.to_s)
            expect(@app.exit_command_counter).to be < 0
          end
        end
      end
    end

    it 'should call command method on self' do
      @app.stub!(:show)
      @app.should_receive(:show)
      @app.process_cmd_line('show')
    end

  end

  context '#handle_exit' do
    context 'command.nil? == true' do
      context 'exit_ok? == false' do
        it 'should increment @exit_command_counter' do
          expect(@app.exit_command_counter).to be == 0
          @app.stub!(:exit_ok?).and_return(false)
          @app.send(:handle_exit)
          expect(@app.exit_command_counter).to be == 1
          @app.send(:handle_exit)
          expect(@app.exit_command_counter).to be == 2
          @app.send(:handle_exit)
          expect(@app.exit_command_counter).to be == 3
        end
      end
    end
  end

  %i[setup start stop abort terminate results].each do |cmd|
    context "##{cmd}" do
      it 'should pass through to :current_project' do
        @app.stub!(:current_project).and_return(mock(Hailstorm::Model::Project).as_null_object)
        @app.current_project.should_receive(cmd)
        @app.send(cmd)
      end
    end
  end

  context '#results' do
    before(:each) do
      @app.stub!(:current_project).and_return(mock(Hailstorm::Model::Project))
    end
    context 'import' do
      it 'should understand file' do
        @app.current_project.should_receive(:results).with(:import, ['foo.jtl', nil])
        @app.send(:results, 'import', 'foo.jtl')
      end
      it 'should understand options' do
        @app.current_project.should_receive(:results).with(:import, [nil, {'jmeter' => '1', 'cluster' => '2'}])
        @app.send(:results, 'import', 'jmeter=1 cluster=2')
      end
      it 'should understand file and options' do
        @app.current_project.should_receive(:results).with(:import, ['/tmp/foo.jtl', {'jmeter' => '1', 'cluster' => '2'}])
        @app.send(:results, 'import', '/tmp/foo.jtl jmeter=1 cluster=2')
      end
      context '<options>' do
        it 'should accept `jmeter` option' do
          @app.current_project.should_receive(:results).with(:import, ['/tmp/foo.jtl', {'jmeter' => '1'}])
          @app.send(:results, 'import', '/tmp/foo.jtl jmeter=1')
        end
        it 'should accept `cluster` option' do
          @app.current_project.should_receive(:results).with(:import, ['/tmp/foo.jtl', {'cluster' => '1'}])
          @app.send(:results, 'import', '/tmp/foo.jtl cluster=1')
        end
        it 'should accept `exec` option' do
          @app.current_project.should_receive(:results).with(:import, ['/tmp/foo.jtl', {'exec' => '1'}])
          @app.send(:results, 'import', '/tmp/foo.jtl exec=1')
        end
        it 'should not accept an unknown option' do
          expect {
            @app.send(:results, 'import', '/tmp/foo.jtl foo=1')
          }.to raise_exception(Hailstorm::Exception)
        end
      end
    end
    context 'with operations that return data' do
      before(:each) do
        @data = [
            OpenStruct.new(id: 3,
                           total_threads_count: 100,
                           avg_90_percentile: 1300.43,
                           avg_tps: 2000.345,
                           formatted_started_at: '2018-01-01 14:10:00',
                           formatted_stopped_at: '2018-01-01 14:25:00')
        ]
      end
      context 'show' do
        it 'should print data' do
          @app.current_project.should_receive(:results).with(:show, nil).and_return(@data)
          @app.send(:results, 'show')
        end
        context 'json format' do
          it 'should print data' do
            @app.current_project.should_receive(:results).with(:show, [1,2,3]).and_return(@data)
            @app.send(:results, 'show', '1:2:3', 'json')
          end
        end
      end
      context 'export' do
        context 'zip format' do
          it 'should create zip file' do
            Zip::File.stub!(:open) do |_zip_file_path, _file_mode, &block|
              zip_file = double('fake_zip_file').as_null_object
              block.call(zip_file)
            end
            @app.current_project.should_receive(:results).with(:export, [1,2,3]).and_return(@data)
            @app.send(:results, 'export', '1:2:3', 'zip')
          end
        end
      end
    end
    it 'should accept "last" as a valid sequence' do
      @app.current_project.should_receive(:results).with(:show, nil).and_return([])
      @app.send(:results, 'show', 'last')
    end
    it 'should accept a Range as a valid sequence' do
      @app.current_project.should_receive(:results).with(:show, [3, 4, 5, 6, 7]).and_return([])
      @app.send(:results, 'show', '3-7')
    end
    it 'should accept a comma or colon separated list of numbers as a valid sequence' do
      @app.current_project.should_receive(:results).with(:show, [3, 4, 5]).and_return([])
      @app.send(:results, 'show', '3,4:5')
    end
  end

  context '#help' do
    before(:each) do
      @help_doc = Hailstorm::Cli::HelpDoc.new
      @mock_help_doc = mock(Hailstorm::Cli::HelpDoc)
      @app.help_doc = @mock_help_doc
    end
    it 'should delegate to @mock_help_doc.help_options' do
      # Workaround for .and_call_original that causes a StackOverflow in underlying JVM
      @mock_help_doc.should_receive(:help_options) { @help_doc.help_options }
      @app.send(:help)
    end
    %w[setup start stop abort terminate results show purge status].each do |cmd|
      it "should delegate to @mock_help_doc.#{cmd}_options" do
        @mock_help_doc.should_receive("#{cmd}_options".to_sym) { @help_doc.send("#{cmd}_options".to_sym) }
        @app.send(:help, cmd)
      end
    end
  end

  context '#purge' do
    before(:each) do
      @app.stub!(:current_project).and_return(mock(Hailstorm::Model::Project))
      @mock_ex_cycle = double('Mock Execution Cycle')
      @app.current_project.stub!(:execution_cycles).and_return([@mock_ex_cycle])
    end
    it 'should destroy all execution_cycles' do
      @mock_ex_cycle.should_receive(:destroy)
      @app.send(:purge)
    end
    context 'tests' do
      it 'should destroy all execution_cycles' do
        @mock_ex_cycle.should_receive(:destroy)
        @app.send(:purge, 'tests')
      end
    end
    context 'clusters' do
      it 'should purge_clusters' do
        @app.current_project.should_receive(:purge_clusters)
        @app.send(:purge, 'clusters')
      end
    end
    context 'all' do
      it 'should destroy current_project' do
        @app.current_project.should_receive(:destroy)
        @app.send(:purge, 'all')
      end
    end
  end

  context '#show' do
    before(:each) do
      @app.stub!(:show_jmeter_plans)
      @app.stub!(:show_load_agents)
      @app.stub!(:show_target_hosts)
    end
    it 'should show everything active' do
      @app.should_receive(:show_jmeter_plans).with(true)
      @app.should_receive(:show_load_agents).with(true)
      @app.should_receive(:show_target_hosts).with(true)
      @app.send(:show)
    end
    context 'jmeter' do
      it 'should show active jmeter' do
        @app.should_receive(:show_jmeter_plans).with(true)
        @app.should_not_receive(:show_load_agents)
        @app.should_not_receive(:show_target_hosts)
        @app.send(:show, 'jmeter')
      end
      context 'all' do
        it 'should show all jmeter' do
          @app.should_receive(:show_jmeter_plans).with(false)
          @app.should_not_receive(:show_load_agents)
          @app.should_not_receive(:show_target_hosts)
          @app.send(:show, 'jmeter', 'all')
        end
      end
    end
    context 'cluster' do
      it 'should show active cluster' do
        @app.should_receive(:show_load_agents).with(true)
        @app.should_not_receive(:show_jmeter_plans)
        @app.should_not_receive(:show_target_hosts)
        @app.send(:show, 'cluster')
      end
      context 'all' do
        it 'should show all cluster' do
          @app.should_receive(:show_load_agents).with(false)
          @app.should_not_receive(:show_jmeter_plans)
          @app.should_not_receive(:show_target_hosts)
          @app.send(:show, 'cluster', 'all')
        end
      end
    end
    context 'monitor' do
      it 'should show active monitor' do
        @app.should_receive(:show_target_hosts).with(true)
        @app.should_not_receive(:show_jmeter_plans)
        @app.should_not_receive(:show_load_agents)
        @app.send(:show, 'monitor')
      end
      context 'all' do
        it 'should show all monitor' do
          @app.should_receive(:show_target_hosts).with(false)
          @app.should_not_receive(:show_jmeter_plans)
          @app.should_not_receive(:show_load_agents)
          @app.send(:show, 'monitor', 'all')
        end
      end
    end
    context 'active' do
      it 'should show everything active' do
        @app.should_receive(:show_jmeter_plans).with(true)
        @app.should_receive(:show_load_agents).with(true)
        @app.should_receive(:show_target_hosts).with(true)
        @app.send(:show, 'active')
      end
    end
    context 'all' do
      it 'should show everything including inactive' do
        @app.should_receive(:show_jmeter_plans).with(false)
        @app.should_receive(:show_load_agents).with(false)
        @app.should_receive(:show_target_hosts).with(false)
        @app.send(:show, 'all')
      end
    end
  end

  context '#status' do
    before(:each) do
      @app.stub!(:current_project).and_return(mock(Hailstorm::Model::Project))
    end
    context 'current_execution_cycle is nil' do
      it 'should not raise_error' do
        @app.current_project.stub!(:current_execution_cycle).and_return(nil)
        expect { @app.send(:status) }.to_not raise_error
      end
    end
    context 'current_execution_cycle is truthy' do
      before(:each) do
        @app.current_project.stub!(:current_execution_cycle).and_return(true)
      end
      context 'no running agents' do
        before(:each) do
          @app.current_project.stub!(:check_status).and_return([])
        end
        it 'should not raise_error' do
          expect { @app.send(:status) }.to_not raise_error
        end
        context 'json format' do
          it 'should not raise_error' do
            expect { @app.send(:status, 'json') }.to_not raise_error
          end
        end
      end
      context 'with running agents' do
        before(:each) do
          check_status_datum = OpenStruct.new(clusterable: OpenStruct.new(slug: 'amazon-east-1'),
                                              public_ip_address: '8.8.8.8',
                                              jmeter_pid: 9364)
          @app.current_project.stub!(:check_status).and_return([check_status_datum])
        end
        it 'should not raise_error' do
          expect { @app.send(:status) }.to_not raise_error
        end
        context 'json format' do
          it 'should not raise_error' do
            expect { @app.send(:status, 'json') }.to_not raise_error
          end
        end
      end
    end
  end

  context '#show_jmeter_plans' do
    context 'only_active is true' do
      it 'should not raise_error' do
        @app.stub!(:current_project).and_return(mock(Hailstorm::Model::Project))
        queryable = double('JMeter Plan Queryable')
        queryable.stub!(:active).and_return([double('Test Plan',
                                                    test_plan_name: 'spec',
                                                    properties_map: { num_threads: 100 })])
        @app.current_project.stub!(:jmeter_plans).and_return(queryable)
        expect { @app.send(:show_jmeter_plans, true) }.to_not raise_error
      end
    end
  end

  context '#show_load_agents' do
    context 'only_active is true' do
      it 'should not raise_error' do
        @app.stub!(:current_project).and_return(mock(Hailstorm::Model::Project))
        load_agent_double = double('Load Agent',
                                   jmeter_plan: double('Test Plan', test_plan_name: 'spec'),
                                   master?: true,
                                   public_ip_address: '8.8.8.8',
                                   jmeter_pid: 9123)
        clusterable = double('Clusterable',
                             slug: 'amazon-us-east-1',
                             load_agents: double('Load Agent Queryable', active: [load_agent_double]))
        cluster = double('Cluster', cluster_code: 'amazon', clusterables: [clusterable])
        @app.current_project.stub!(:clusters).and_return([cluster])
        expect { @app.send(:show_load_agents, true) }.to_not raise_error
      end
    end
  end

  context '#show_target_hosts' do
    context 'only_active is true' do
      it 'should not raise_error' do
        target_host = double('TargetHost',
                             role_name: 'server',
                             host_name: 'app.de.mon',
                             class: Hailstorm::Model::Nmon,
                             executable_pid: 2345)
        @app.stub!(:current_project).and_return(mock(Hailstorm::Model::Project))
        @app.current_project.stub!(:target_hosts).and_return(double('Queryable',
                                                                    active: double('Natural Orderable',
                                                                                   natural_order: [target_host])))
        expect { @app.send(:show_target_hosts, true) }.to_not raise_error
      end
    end
  end
end
