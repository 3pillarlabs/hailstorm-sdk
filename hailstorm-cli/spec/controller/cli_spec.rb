require 'spec_helper'

require 'active_record/base'
require 'hailstorm/exceptions'
require 'hailstorm/controller/cli'

describe Hailstorm::Controller::Cli do
  before(:each) do
    @middleware = Hailstorm.application
    @app = Hailstorm::Controller::Cli.new(@middleware)
    expect(@app.cmd_history).to respond_to(:saved_history_path)
    @app.cmd_history.stub!(:saved_history_path).and_return(File.join(Hailstorm.root, 'spec_hailstorm_history'))
    ActiveRecord::Base.stub!(:clear_all_connections!)
  end

  context '#process_commands' do
    before(:each) do
      @middleware.stub!(:config_serial_version).and_return('A')
      @app.stub!(:settings_modified?).and_return(false)
    end

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
      @app.cmd_history.should_not_receive(:save_history)
      cmds_ite = ['', nil].each
      Readline.stub!(:readline) { |_p, _h| cmds_ite.next }
      @app.process_commands
    end
    it 'should try interpret a command' do
      @app.cmd_history.should_receive(:save_history).with('help')
      cmds_ite = ['help', nil].each
      Readline.stub!(:readline) { |_p, _h| cmds_ite.next }
      @app.process_commands
    end
    it 'should try interpret multiple commands' do
      cmds = ['help', 'start', 'stop', 'setup', 'results', nil]
      @app.cmd_history.should_receive(:save_history).exactly(cmds.length - 1).times
      cmds_ite = cmds.each
      Readline.stub!(:readline) { |_p, _h| cmds_ite.next }
      @app.process_commands
    end
    context "'start' command" do
      it 'should modify the readline prompt' do
        @middleware.stub!(:config_serial_version).and_return('A')
        @app.stub!(:settings_modified?).and_return(false)
        cmds_ite = ['start', nil].each_with_index
        Readline.stub!(:readline) do |_p, _h|
          cmd, idx = cmds_ite.next
          expect(_p).to match(/\*\s+$/) if idx > 0
          cmd
        end
        @app.cmd_executor.stub!(:interpret_execute).and_return(:start)
        @app.process_commands
      end
    end
    context "'stop', 'abort' command" do
      it 'should modify the readline prompt' do
        cmds_ite = ['stop', 'abort', nil].each_with_index
        Readline.stub!(:readline) do |_p, _h|
          cmd, idx = cmds_ite.next
          expect(_p).to_not match(/\*\s+$/) if idx > 0
          cmd
        end
        @app.cmd_executor.stub!(:interpret_execute) { |cmds| cmds[0].to_sym }
        @app.process_commands
      end
    end
    it 'should rescue IncorrectCommandException' do
      @app.cmd_history.should_receive(:save_history).with('help coffee')
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
          @app.cmd_history.should_receive(:save_history).exactly(cmds.length - 1).times
          @app.process_commands
        end
        it 'should rescue evaluation exception/error' do
          @app.cmd_history.should_receive(:save_history).with('puts "Hello, World')
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
          Readline.stub!(:readline) { |_p, _h| cmds_ite.next }
          @app.cmd_history.should_receive(:save_history).once
          @app.process_commands
        end
      end
    end
    it 'should rescue Hailstorm::ThreadJoinException' do
      @app.cmd_history.should_receive(:save_history).with('start redeploy')
      @app.cmd_executor.stub!(:interpret_execute)
          .and_raise(Hailstorm::ThreadJoinException.new(StandardError.new('mock error')))
      cmds_ite = ['start redeploy', nil].each
      Readline.stub!(:readline) { |_p, _h| cmds_ite.next }
      @app.process_commands
    end
    it 'should rescue Hailstorm::Exception' do
      @app.cmd_history.should_receive(:save_history).with('results')
      @app.cmd_executor.stub!(:interpret_execute).and_raise(Hailstorm::Exception, 'mock error')
      cmds_ite = ['results', nil].each
      Readline.stub!(:readline) { |_p, _h| cmds_ite.next }
      @app.process_commands
    end
    it 'should rescue StandardError' do
      @app.cmd_history.should_receive(:save_history).with('setup')
      @app.cmd_executor.stub!(:interpret_execute).and_raise(StandardError, 'mock error')
      cmds_ite = ['setup', nil].each
      Readline.stub!(:readline) { |_p, _h| cmds_ite.next }
      @app.process_commands
    end
  end

  context '#process_cmd_line' do
    before(:each) do
      @middleware.stub!(:config_serial_version).and_return('A')
      @app.stub!(:settings_modified?).and_return(false)
    end

    %i[quit exit].each do |cmd|
      context 'exit_ok? == true' do
        context "'#{cmd}' command" do
          it 'should set @exit_command_counter < 0' do
            @app.cmd_executor.stub!(:interpret_execute) { |cmds| cmds[0].to_sym }
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
          @app.cmd_executor.stub!(:interpret_execute) { |cmds| cmds[0].to_sym }
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

    context '#settings_modified? == true' do
      it 'should reload the configuration' do
        @app.unstub!(:settings_modified?)
        @app.stub!(:settings_modified?).and_return(true)
        @middleware.should_receive(:load_config)
        project = Hailstorm::Model::Project.new
        @app.stub!(:current_project).and_return(project)
        @app.process_cmd_line('help')
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

  context '#settings_modified?' do
    it 'should be true if project is not upto date with configuration' do
      project = Hailstorm::Model::Project.new(serial_version: 'A')
      @app.stub!(:current_project).and_return(project)
      expect(@app.send(:settings_modified?, 'B')).to be_true
    end
  end
end
