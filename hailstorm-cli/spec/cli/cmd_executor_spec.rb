require 'spec_helper'
require 'hailstorm/cli/cmd_executor'
require 'hailstorm/cli/help_doc'
require 'hailstorm/model/project'

describe Hailstorm::Cli::CmdExecutor do
  before(:each) do
    middleware = Hailstorm.application
    project = spy(Hailstorm::Model::Project)
    @app = Hailstorm::Cli::CmdExecutor.new(middleware, project)
  end

  context '#interpret_execute' do
    it 'should call interpreted command method on template' do
      allow(@app).to receive(:command_execution_template).and_return(instance_double(Hailstorm::Middleware::CommandExecutionTemplate))
      expect(@app.command_execution_template).to receive(:start)
      @app.interpret_execute('start')
    end

    context "'help' command" do
      it 'should call help on self' do
        expect(@app).to receive(:help)
        @app.interpret_execute('help')
      end
      it 'should call help with additional arguments' do
        expect(@app).to receive(:help).with('start')
        @app.interpret_execute('help start')
      end
    end

    context "'show' command" do
      it 'should call show on self' do
        expect(@app).to receive(:show)
        @app.interpret_execute('show')
      end
    end
    it 'should modify sequences to be array of file paths in default results import directory' do
      allow(Dir).to receive('[]'.to_sym).and_return(%w[b.jtl a.jtl])
      expect(@app.command_execution_template).to receive(:results).with(false, nil, :import, [%w[a.jtl b.jtl], nil])
      @app.interpret_execute('results import')
    end
  end

  context '#help' do
    before(:each) do
      @orig_help_doc = @app.help_doc(File.expand_path('../../../templates/cli/help_docs.yml', __FILE__))
      allow(@app).to receive(:help_doc).and_return(instance_double(Hailstorm::Cli::HelpDoc))
    end
    it 'should delegate to @mock_help_doc.help_options' do
      # Workaround for .and_call_original that causes a StackOverflow in underlying JVM
      expect(@app.help_doc).to receive(:help_options) { @orig_help_doc.help_options }
      @app.send(:help)
    end
    %w[setup start stop abort terminate results show purge status].each do |cmd|
      it "should delegate to @mock_help_doc.#{cmd}_options" do
        expect(@app.help_doc).to receive("#{cmd}_options".to_sym) { @orig_help_doc.send("#{cmd}_options".to_sym) }
        @app.send(:help, cmd)
      end
    end
  end

  context '#execute_method_args' do
    it 'should call view_renderer.render_results' do
      allow(@app.command_execution_template).to receive(:results).and_return([[], :show])
      expect(@app.view_renderer).to receive(:render_results).and_return(nil)
      @app.interpret_execute('results')
    end
    it 'should call view_renderer.render_setup' do
      allow(@app.command_execution_template).to receive(:setup)
      expect(@app.view_renderer).to receive(:render_setup).and_return(nil)
      @app.interpret_execute('setup')
    end
    it 'should call view_renderer.render_status' do
      allow(@app.command_execution_template).to receive(:status).and_return(nil)
      expect(@app.view_renderer).to receive(:render_status)
      @app.interpret_execute('status')
    end

    context "'results import' command" do
      it 'should modify sequences to be array of file paths in default results import directory and options' do
        allow(Dir).to receive('[]'.to_sym).and_return(%w[b.jtl a.jtl])
        expect(@app.command_execution_template).to receive(:results)
          .with(false, nil, :import, [%w[a.jtl b.jtl], {'jmeter' => '1', 'cluster' => '2'}])
        @app.execute_method_args([false, nil, :import, [nil, {'jmeter' => '1', 'cluster' => '2'}]],
                                 :results)
      end
    end
  end

  context '#show' do
    before(:each) do
      allow(@app).to receive(:project).and_return(Hailstorm::Model::Project.create!(project_code: 'cmd_executor_spec'))
    end
    it 'should show active by default' do
      expect(@app.view_renderer).to receive(:render_show) do |_q, show_active, what|
        expect(show_active).to be true
        expect(what).to be == :active
      end
      @app.show
    end
    it 'should should active jmeter|cluster|target_host' do
      expect(@app.view_renderer).to receive(:render_show) do |_q, show_active, what|
        expect(show_active).to be true
        expect(what).to be == :jmeter
      end
      @app.show('jmeter')
    end
    it '"all" should set show_active = false' do
      expect(@app.view_renderer).to receive(:render_show) do |_q, show_active, what|
        expect(show_active).to be false
        expect(what).to be == :all
      end
      @app.show('all')
    end
  end
end
