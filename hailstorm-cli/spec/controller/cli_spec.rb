require 'spec_helper'

require 'active_record/base'
require 'hailstorm/exceptions'
require 'hailstorm/controller/cli'

describe Hailstorm::Controller::Cli do
  before(:each) do
    @middleware = Hailstorm.application
    @app = Hailstorm::Controller::Cli.new(@middleware)
    expect(@app.cmd_history).to respond_to(:saved_history_path)
    allow(@app.cmd_history).to receive(:saved_history_path).and_return(File.join(Hailstorm.root, 'spec_hailstorm_history'))
    allow(ActiveRecord::Base).to receive(:clear_all_connections!)
  end

  context '#process_commands' do
    before(:each) do
      allow(@middleware).to receive(:config_serial_version).and_return('A')
      allow(@app).to receive(:settings_modified?).and_return(false)
    end

    context 'nil command' do
      context 'exit_ok? == true' do
        it 'should set @exit_command_counter < 0' do
          expect(@app.exit_command_counter).to be == 0
          allow(Readline).to receive(:readline).and_return(nil)
          allow(@app).to receive(:exit_ok?).and_return(true)
          @app.process_commands
          expect(@app.exit_command_counter).to be < 0
        end
      end
    end
    it 'should skip empty lines' do
      expect(@app.cmd_history).to_not receive(:save_history)
      cmds_ite = ['', nil].each
      allow(Readline).to receive(:readline) { |_p, _h| cmds_ite.next }
      @app.process_commands
    end
    it 'should try interpret a command' do
      expect(@app.cmd_history).to receive(:save_history).with('help')
      cmds_ite = ['help', nil].each
      allow(Readline).to receive(:readline) { |_p, _h| cmds_ite.next }
      @app.process_commands
    end
    it 'should try interpret multiple commands' do
      cmds = ['help', 'start', 'stop', 'setup', 'results', nil]
      expect(@app.cmd_history).to receive(:save_history).exactly(cmds.length - 1).times
      cmds_ite = cmds.each
      allow(Readline).to receive(:readline) { |_p, _h| cmds_ite.next }
      @app.process_commands
    end

    context '#enhanced_prompt'  do
      before(:each) do
        @project = Hailstorm::Model::Project.new
        expect(@project).to respond_to(:current_execution_cycle)
        allow(@app).to receive(:current_project).and_return(@project)
      end

      context 'when tests are running' do
        it 'should display an indented prompt' do
          allow(@project).to receive(:current_execution_cycle).and_return(Hailstorm::Model::ExecutionCycle.new)
          expect(@app.send(:enhanced_prompt)).to match(/\*\s+$/)
        end
      end

      context 'when tests are not running' do
        it 'should remove the indentation from the prompt' do
          allow(@project).to receive(:current_execution_cycle).and_return(nil)
          expect(@app.send(:enhanced_prompt)).to_not match(/\*\s+$/)
        end
      end
    end

    it 'should rescue IncorrectCommandException' do
      expect(@app.cmd_history).to receive(:save_history).with('help coffee')
      cmds_ite = ['help coffee', nil].each
      allow(Readline).to receive(:readline) { |_p, _h| cmds_ite.next }
      @app.process_commands
    end
    context 'rescue UnknownCommandException' do
      context 'Hailstorm.is_production? == false' do
        before(:each) do
          allow(Hailstorm).to receive(:production?).and_return(false)
        end
        it 'should evaluate command as Ruby' do
          cmds = ['puts "Hello, World"', '1 + 2', 'hello', nil]
          cmds_ite = cmds.each
          allow(Readline).to receive(:readline) { |_p, _h| cmds_ite.next }
          expect(@app.cmd_history).to receive(:save_history).exactly(cmds.length - 1).times
          @app.process_commands
        end
        it 'should rescue evaluation exception/error' do
          expect(@app.cmd_history).to receive(:save_history).with('puts "Hello, World')
          cmds_ite = ['puts "Hello, World', nil].each
          allow(Readline).to receive(:readline) { |_p, _h| cmds_ite.next }
          @app.process_commands
        end
      end
      context 'Hailstorm.is_production? == true' do
        it 'should save the commands in history' do
          allow(Hailstorm).to receive(:production?).and_return(true)
          cmds = ['puts "Hello, World"', nil]
          cmds_ite = cmds.each
          allow(Readline).to receive(:readline) { |_p, _h| cmds_ite.next }
          expect(@app.cmd_history).to receive(:save_history).once
          @app.process_commands
        end
      end
    end
    it 'should rescue Hailstorm::ThreadJoinException' do
      expect(@app.cmd_history).to receive(:save_history).with('start redeploy')
      exception = Hailstorm::ThreadJoinException.new(StandardError.new('mock error'))
      allow(@app.cmd_executor).to receive(:interpret_execute).and_raise(exception)
      cmds_ite = ['start redeploy', nil].each
      allow(Readline).to receive(:readline) { |_p, _h| cmds_ite.next }
      @app.process_commands
    end
    it 'should rescue Hailstorm::Exception' do
      expect(@app.cmd_history).to receive(:save_history).with('results')
      allow(@app.cmd_executor).to receive(:interpret_execute).and_raise(Hailstorm::Exception, 'mock error')
      cmds_ite = ['results', nil].each
      allow(Readline).to receive(:readline) { |_p, _h| cmds_ite.next }
      @app.process_commands
    end
    it 'should rescue StandardError' do
      expect(@app.cmd_history).to receive(:save_history).with('setup')
      allow(@app.cmd_executor).to receive(:interpret_execute).and_raise(StandardError, 'mock error')
      cmds_ite = ['setup', nil].each
      allow(Readline).to receive(:readline) { |_p, _h| cmds_ite.next }
      @app.process_commands
    end
  end

  context '#process_cmd_line' do
    before(:each) do
      allow(@middleware).to receive(:config_serial_version).and_return('A')
      allow(@app).to receive(:settings_modified?).and_return(false)
    end

    %i[quit exit].each do |cmd|
      context 'exit_ok? == true' do
        context "'#{cmd}' command" do
          it 'should set @exit_command_counter < 0' do
            allow(@app.cmd_executor).to receive(:interpret_execute) { |cmds| cmds[0].to_sym }
            expect(@app.exit_command_counter).to be == 0
            allow(@app).to receive(:exit_ok?).and_return(true)
            @app.process_cmd_line(cmd.to_s)
            expect(@app.exit_command_counter).to be < 0
          end
        end
      end

      context 'exit_ok? == false' do
        before(:each) do
          allow(@app).to receive(:exit_ok?).and_return(false)
          allow(@app.cmd_executor).to receive(:interpret_execute) { |cmds| cmds[0].to_sym }
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
        allow(@app).to receive(:settings_modified?).and_return(true)
        expect(@middleware).to receive(:load_config)
        project = Hailstorm::Model::Project.new
        allow(@app).to receive(:current_project).and_return(project)
        @app.process_cmd_line('help')
      end
    end
  end

  context '#handle_exit' do
    context 'command.nil? == true' do
      context 'exit_ok? == false' do
        it 'should increment @exit_command_counter' do
          expect(@app.exit_command_counter).to be == 0
          allow(@app).to receive(:exit_ok?).and_return(false)
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
      allow(@app).to receive(:current_project).and_return(project)
      expect(@app.send(:settings_modified?, 'B')).to be true
    end
  end
end
