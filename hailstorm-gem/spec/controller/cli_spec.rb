require 'spec_helper'

require 'active_record/base'
require 'hailstorm/exceptions'
require 'hailstorm/controller/cli'
require 'hailstorm/model/project'
require 'hailstorm/model/nmon'
require 'hailstorm/cli/help_doc'
require 'hailstorm/cli/view_template'

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
    context "'start' command" do
      it 'should modify the readline prompt' do
        @app.stub!(:command_execution_template).and_return(mock(Hailstorm::Middleware::CommandExecutionTemplate))
        cmds_ite = ['start', nil].each_with_index
        Readline.stub!(:readline) do |_p, _h|
          cmd, idx = cmds_ite.next
          expect(_p).to match(/\*\s+$/) if idx > 0
          cmd
        end
        @app.command_execution_template.should_receive(:start)
        @app.process_commands
      end
    end
    context "'stop', 'abort' command" do
      it 'should modify the readline prompt' do
        mock_cmd_ex_tmpl = mock(Hailstorm::Middleware::CommandExecutionTemplate)
        mock_cmd_ex_tmpl.stub!(:stop)
        mock_cmd_ex_tmpl.stub!(:abort)
        @app.stub!(:command_execution_template).and_return(mock_cmd_ex_tmpl)
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
      context 'Hailstorm.is_production? == true' do
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
      @app.stub!(:command_execution_template).and_return(mock(Hailstorm::Middleware::CommandExecutionTemplate))
      @app.command_execution_template.stub!(:start).and_raise(Hailstorm::ThreadJoinException,
                                                              'mock Hailstorm::ThreadJoinException')
      cmds_ite = ['start redeploy', nil].each
      Readline.stub!(:readline) { |_p, _h| cmds_ite.next }
      @app.process_commands
    end
    it 'should rescue Hailstorm::Exception' do
      @app.should_receive(:save_history).with('results')
      @app.stub!(:command_execution_template).and_return(mock(Hailstorm::Middleware::CommandExecutionTemplate))
      @app.command_execution_template.stub!(:results).and_raise(Hailstorm::Exception)
      cmds_ite = ['results', nil].each
      Readline.stub!(:readline) { |_p, _h| cmds_ite.next }
      @app.process_commands
    end
    it 'should rescue StandardError' do
      @app.should_receive(:save_history).with('setup')
      @app.stub!(:command_execution_template).and_return(mock(Hailstorm::Middleware::CommandExecutionTemplate))
      @app.command_execution_template.stub!(:setup).and_raise(StandardError)
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

    context 'show' do
      it 'should call command method on self' do
        @app.stub!(:show)
        @app.should_receive(:show)
        @app.process_cmd_line('show')
      end
    end

    it 'should call interpreted command method on template' do
      @app.stub!(:command_execution_template)
      @app.should_receive(:command_execution_template)
      @app.process_cmd_line('start')
    end

    context 'responds_to render_ method_name' do
      it 'should call render_results on self' do
        @app.command_execution_template.stub!(:results).and_return([[], :show])
        @app.view_template.should_receive(:render_results_show).and_return(nil)
        @app.process_cmd_line('results')
      end
      it 'should call render_setup' do
        @app.stub!(:current_project).and_return(mock(Hailstorm::Model::Project).as_null_object)
        @app.command_execution_template.stub!(:setup)
        @app.view_template.should_receive(:render_jmeter_plans).and_return(nil)
        @app.stub!(:render_default)
        @app.process_cmd_line('setup')
      end
      it 'should call render_status' do
        @app.command_execution_template.stub!(:status).and_return(nil)
        @app.process_cmd_line('status')
      end
    end

    context "'help' command" do
      it 'should call help on self' do
        @app.should_receive(:help)
        @app.process_cmd_line('help')
      end
      it 'should call help with additional arguments' do
        @app.should_receive(:help).with('start')
        @app.process_cmd_line('help start')
      end
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

  context '#help' do
    before(:each) do
      @orig_help_doc = @app.help_doc
      @app.stub!(:help_doc).and_return(mock(Hailstorm::Cli::HelpDoc))
    end
    it 'should delegate to @mock_help_doc.help_options' do
      # Workaround for .and_call_original that causes a StackOverflow in underlying JVM
      @app.help_doc.should_receive(:help_options) { @orig_help_doc.help_options }
      @app.send(:help)
    end
    %w[setup start stop abort terminate results show purge status].each do |cmd|
      it "should delegate to @mock_help_doc.#{cmd}_options" do
        @app.help_doc.should_receive("#{cmd}_options".to_sym) { @orig_help_doc.send("#{cmd}_options".to_sym) }
        @app.send(:help, cmd)
      end
    end
  end

  context '#show' do
    before(:each) do
      mock_project = mock(Hailstorm::Model::Project)
      @active_queryable = double('Queryable Active', natural_order: [])
      @queryable = double('Queryable', active: @active_queryable, natural_order: [])
      %i[jmeter_plans clusters target_hosts].each do |sym|
        mock_project.stub!(sym).and_return(@queryable)
      end
      @app.stub!(:current_project).and_return(mock_project)
      @app.stub!(:view_template).and_return(mock(Hailstorm::Cli::ViewTemplate))
      %i[render_jmeter_plans render_load_agents render_target_hosts].each do |sym|
        @app.view_template.stub!(sym).and_return(sym)
      end
    end
    it 'should show everything active' do
      @app.view_template.should_receive(:render_jmeter_plans) { |_q, flag| expect(flag).to be_true }
      @app.view_template.should_receive(:render_load_agents) { |_q, flag| expect(flag).to be_true }
      @app.view_template.should_receive(:render_target_hosts) { |_q, flag| expect(flag).to be_true }
      @app.send(:show)
    end
    context 'jmeter' do
      it 'should show active jmeter' do
        @app.view_template.should_receive(:render_jmeter_plans) { |_q, flag| expect(flag).to be_true }
        @app.view_template.should_not_receive(:render_load_agents)
        @app.view_template.should_not_receive(:render_target_hosts)
        @app.send(:show, 'jmeter')
      end
      context 'all' do
        it 'should show all jmeter' do
          @app.view_template.should_receive(:render_jmeter_plans) { |_q, flag| expect(flag).to be_false }
          @app.view_template.should_not_receive(:render_load_agents)
          @app.view_template.should_not_receive(:render_target_hosts)
          @app.send(:show, 'jmeter', 'all')
        end
      end
    end
    context 'cluster' do
      it 'should show active cluster' do
        @app.view_template.should_receive(:render_load_agents) { |_q, flag| expect(flag).to be_true }
        @app.view_template.should_not_receive(:render_jmeter_plans)
        @app.view_template.should_not_receive(:render_target_hosts)
        @app.send(:show, 'cluster')
      end
      context 'all' do
        it 'should show all cluster' do
          @app.view_template.should_receive(:render_load_agents) { |_q, flag| expect(flag).to be_false }
          @app.view_template.should_not_receive(:render_jmeter_plans)
          @app.view_template.should_not_receive(:render_target_hosts)
          @app.send(:show, 'cluster', 'all')
        end
      end
    end
    context 'monitor' do
      it 'should show active monitor' do
        @app.view_template.should_receive(:render_target_hosts) { |_q, flag| expect(flag).to be_true }
        @app.view_template.should_not_receive(:render_jmeter_plans)
        @app.view_template.should_not_receive(:render_load_agents)
        @app.send(:show, 'monitor')
      end
      context 'all' do
        it 'should show all monitor' do
          @app.view_template.should_receive(:render_target_hosts) { |_q, flag| expect(flag).to be_false }
          @app.view_template.should_not_receive(:render_jmeter_plans)
          @app.view_template.should_not_receive(:render_load_agents)
          @app.send(:show, 'monitor', 'all')
        end
      end
    end
    context 'active' do
      it 'should show everything active' do
        @app.view_template.should_receive(:render_jmeter_plans) { |_q, flag| expect(flag).to be_true }
        @app.view_template.should_receive(:render_load_agents) { |_q, flag| expect(flag).to be_true }
        @app.view_template.should_receive(:render_target_hosts) { |_q, flag| expect(flag).to be_true }
        @app.send(:show, 'active')
      end
    end
    context 'all' do
      it 'should show everything including inactive' do
        @app.view_template.should_receive(:render_jmeter_plans) { |_q, flag| expect(flag).to be_false }
        @app.view_template.should_receive(:render_load_agents) { |_q, flag| expect(flag).to be_false }
        @app.view_template.should_receive(:render_target_hosts) { |_q, flag| expect(flag).to be_false }
        @app.send(:show, 'all')
      end
    end
  end

  context '#render_status' do
    before(:each) do
      @app.stub!(:view_template).and_return(mock(Hailstorm::Cli::ViewTemplate))
    end
    context 'load generation in progress' do
      it 'should show running agents' do
        @app.view_template.should_receive(:render_running_agents)
        @app.render_status([{}])
      end
    end
    context 'load generation finished' do
      it 'should show no running agents' do
        @app.view_template.should_not_receive(:render_running_agents)
        @app.render_status([], :json)
      end
    end
  end
end
