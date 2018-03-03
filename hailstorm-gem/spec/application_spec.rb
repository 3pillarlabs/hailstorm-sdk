require 'spec_helper'
require 'hailstorm/application'
require 'hailstorm/model/project'
require 'hailstorm/model/load_agent'
require 'hailstorm/exceptions'

describe Hailstorm::Application do

  context '#interpret_command' do
    context 'results' do
      before(:each) do
        @app = Hailstorm::Application.new
      end
      it 'should interpret \'results\'' do
        @app.should_receive(:results)
        @app.interpret_command('results')
      end
      %w[show exclude include report export import].each do |sc|
        it "should interpret 'results #{sc}'" do
          @app.should_receive(:results).with(sc)
          @app.interpret_command("results #{sc}")
        end
      end
      it 'should interpret \'results import <path-spec>\'' do
        @app.should_receive(:results).with('import', '/tmp/b23d8/foo.jtl')
        @app.interpret_command('results import /tmp/b23d8/foo.jtl')
      end
      it 'should interpret \'results help\'' do
        @app.should_receive(:help).with(:results)
        @app.interpret_command('results help')
      end
      it 'should interpret \'results show last\'' do
        @app.should_receive(:results).with('show', 'last')
        @app.interpret_command('results show last')
      end
      it 'should interpret \'results last\'' do
        @app.should_receive(:results).with('last')
        @app.interpret_command('results last')
      end
      %w[1,2,3 4-8 7:8:9].each do |seq|
        %w[show exclude include report export].each do |sc|
          it "should interpret 'results #{sc} #{seq}'" do
            @app.should_receive(:results).with(sc, seq)
            @app.interpret_command("results #{sc} #{seq}")
          end
        end
      end
    end
    context 'quit or exit' do
      before(:each) do
        @app = Hailstorm::Application.new
        project = mock(Hailstorm::Model::Project)
        project.stub(:load_agents) {  [Hailstorm::Model::LoadAgent.new] }
        @app.stub!(:current_project) { project }
      end
      context 'exit_ok? == true' do
        it 'should set @exit_command_counter < 0' do
          @app.current_project.stub(:load_agents) { [] }
          @app.interpret_command('quit')
          expect(@app.instance_variable_get('@exit_command_counter')).to be < 0
        end
      end
      context 'exit_ok? == false' do
        it 'should increment @exit_command_counter once' do
          @app.interpret_command('exit')
          expect(@app.instance_variable_get('@exit_command_counter')).to be > 0
        end
        it 'should set @exit_command_counter < 0 twice' do
          @app.interpret_command('exit')
          @app.interpret_command('exit')
          expect(@app.instance_variable_get('@exit_command_counter')).to be < 0
        end
      end
    end
    context 'args as a Hash' do
      it 'should interpret command, arguments and format' do
        app = Hailstorm::Application.new
        app.stub(:results)
        app.should_receive(:results).with('export', '1-3', 'json')
        app.interpret_command(args: %w[export 1-3], command: 'results', format: 'json')
      end
    end
    context 'help' do
      before(:each) do
        @app = Hailstorm::Application.new
      end
      it 'should interpret \'help\'' do
        @app.should_receive(:help)
        @app.interpret_command('help')
      end
      %w[setup start stop abort terminate results purge show status].each do |sc|
        it "should interpret 'help #{sc}'" do
          @app.should_receive(:help).with(sc)
          @app.interpret_command("help #{sc}")
        end
      end
    end
    context 'setup' do
      before(:each) do
        @app = Hailstorm::Application.new
      end
      it 'should interpret \'setup\'' do
        @app.should_receive(:setup)
        @app.interpret_command('setup')
      end
      it 'should interpret \'setup force\'' do
        @app.should_receive(:setup).with('force')
        @app.interpret_command('setup force')
      end
      it 'should interpret \'setup help\'' do
        @app.should_receive(:help).with(:setup)
        @app.interpret_command('setup help')
      end
    end
    context 'start' do
      before(:each) do
        @app = Hailstorm::Application.new
      end
      it 'should interpret \'start\'' do
        @app.should_receive(:start)
        @app.interpret_command('start')
      end
      it 'should interpret \'start redeploy\'' do
        @app.should_receive(:start).with('redeploy')
        @app.interpret_command('start redeploy')
      end
      it 'should interpret \'start help\'' do
        @app.should_receive(:help).with(:start)
        @app.interpret_command('start help')
      end
    end
    context 'stop' do
      before(:each) do
        @app = Hailstorm::Application.new
      end
      it 'should interpret \'stop\'' do
        @app.should_receive(:stop)
        @app.interpret_command('stop')
      end
      ['suspend', 'wait', 'suspend wait', 'wait suspend'].each do |sc|
        it "should interpret 'stop #{sc}'" do
          @app.should_receive(:stop).with(sc)
          @app.interpret_command("stop #{sc}")
        end
      end
      it 'should interpret \'stop help\'' do
        @app.should_receive(:help).with(:stop)
        @app.interpret_command('stop help')
      end
    end
    context 'abort' do
      before(:each) do
        @app = Hailstorm::Application.new
      end
      it 'should interpret \'abort\'' do
        @app.should_receive(:abort)
        @app.interpret_command('abort')
      end
      it 'should interpret \'abort suspend\'' do
        @app.should_receive(:abort).with('suspend')
        @app.interpret_command('abort suspend')
      end
      it 'should interpret \'abort help\'' do
        @app.should_receive(:help).with(:abort)
        @app.interpret_command('abort help')
      end
    end
    context 'purge' do
      before(:each) do
        @app = Hailstorm::Application.new
      end
      it 'should interpret \'purge\'' do
        @app.should_receive(:purge)
        @app.interpret_command('purge')
      end
      %w[tests clusters all].each do |sc|
        it "should interpret 'purge #{sc}'" do
          @app.should_receive(:purge).with(sc)
          @app.interpret_command("purge #{sc}")
        end
      end
      it 'should interpret \'purge help\'' do
        @app.should_receive(:help).with(:purge)
        @app.interpret_command('purge help')
      end
    end
    context 'show' do
      before(:each) do
        @app = Hailstorm::Application.new
      end
      it 'should interpret \'show\'' do
        @app.should_receive(:show)
        @app.interpret_command('show')
      end
      %w[jmeter cluster monitor active].each do |sc|
        it "should interpret 'show #{sc}'" do
          @app.should_receive(:show).with(sc)
          @app.interpret_command("show #{sc}")
        end
        it "should interpret 'show #{sc} all'" do
          @app.should_receive(:show).with(sc, 'all')
          @app.interpret_command("show #{sc} all")
        end
      end
      it 'should interpret \'show help\'' do
        @app.should_receive(:help).with(:show)
        @app.interpret_command('show help')
      end
    end
    context 'terminate' do
      before(:each) do
        @app = Hailstorm::Application.new
      end
      it 'should interpret \'terminate\'' do
        @app.should_receive(:terminate)
        @app.interpret_command('terminate')
      end
      it 'should interpret \'terminate help\'' do
        @app.should_receive(:help).with(:terminate)
        @app.interpret_command('terminate help')
      end
    end
    context 'status' do
      before(:each) do
        @app = Hailstorm::Application.new
      end
      it 'should interpret \'status\'' do
        @app.should_receive(:status)
        @app.interpret_command('status')
      end
      it 'should interpret \'status help\'' do
        @app.should_receive(:help).with(:status)
        @app.interpret_command('status help')
      end
    end
    context 'unknown command' do
      it 'should raise exception' do
        app = Hailstorm::Application.new
        expect { app.interpret_command('make coffee') }.to raise_error(Hailstorm::Application::UnknownCommandException)
      end
    end
  end

  context '#results' do
    context 'import' do
      before(:each) do
        @app = Hailstorm::Application.new
        class << @app
          include RSpec::Mocks::ExampleMethods
          def current_project
            if @current_project.nil?
              @current_project = mock(Hailstorm::Model::Project)
              @current_project.stub!(:results)
            end
            @current_project
          end
        end
      end
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
  end

  context '#create_project' do
    it 'should create the Hailstorm application project structure' do
      app = Hailstorm::Application.new
      root_path = Dir.mktmpdir
      app_name = 'spec'
      app.create_project(root_path, app_name, true, '/usr/local/lib/hailstorm-gem')

      expect(File.directory?(File.join(root_path, app_name, Hailstorm.db_dir))).to be_true
      expect(File.directory?(File.join(root_path, app_name, Hailstorm.app_dir))).to be_true
      expect(File.directory?(File.join(root_path, app_name, Hailstorm.log_dir))).to be_true
      expect(File.directory?(File.join(root_path, app_name, Hailstorm.tmp_dir))).to be_true
      expect(File.directory?(File.join(root_path, app_name, Hailstorm.reports_dir))).to be_true
      expect(File.directory?(File.join(root_path, app_name, Hailstorm.config_dir))).to be_true
      expect(File.directory?(File.join(root_path, app_name, Hailstorm.vendor_dir))).to be_true
      expect(File.directory?(File.join(root_path, app_name, Hailstorm.script_dir))).to be_true


      expect(File.exist?(File.join(root_path, app_name, 'Gemfile'))).to be_true
      expect(File.exist?(File.join(root_path, app_name, Hailstorm.script_dir, 'hailstorm'))).to be_true
      expect(File.exist?(File.join(root_path, app_name, Hailstorm.config_dir, 'environment.rb'))).to be_true
      expect(File.exist?(File.join(root_path, app_name, Hailstorm.config_dir, 'database.properties'))).to be_true
      expect(File.exist?(File.join(root_path, app_name, Hailstorm.config_dir, 'boot.rb'))).to be_true

      FileUtils.rm_rf(root_path)
    end
  end

  context '#process_commands' do
    before(:each) do
      @app = Hailstorm::Application.new
      @app.stub!(:saved_history_path).and_return(File.join(java.lang.System.getProperty('user.home'),
                                                 '.spec_hailstorm_history'))
      ActiveRecord::Base.stub!(:clear_all_connections!)
    end
    context 'nil command' do
      it 'should exit if exit_ok? == true' do
        Readline.stub!(:readline).and_return(nil)
        @app.process_commands
        expect(@app.instance_variable_get('@exit_command_counter')).to be < 0
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
      context 'Hailstorm.env != production' do
        it 'should evaluate command as Ruby' do
          @app.should_receive(:save_history).twice
          cmds_ite = ['puts "Hello, World"', '1 + 2', nil].each
          Readline.stub!(:readline) { |_p, _h| cmds_ite.next }
          @app.process_commands
        end
        it 'should rescue evaluation exception/error' do
          @app.should_receive(:save_history).with('puts "Hello, World')
          cmds_ite = ['puts "Hello, World', nil].each
          Readline.stub!(:readline) { |_p, _h| cmds_ite.next }
          @app.process_commands
        end
      end
    end
    it 'should rescue Hailstorm::ThreadJoinException' do
      @app.should_receive(:save_history).with('start redeploy')
      @app.stub!(:interpret_command).and_raise(Hailstorm::ThreadJoinException.new(nil))
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
end
