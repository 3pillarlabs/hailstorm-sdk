require 'spec_helper'
require 'hailstorm/cli/cmd_executor'
require 'hailstorm/cli/help_doc'
require 'hailstorm/model/project'

describe Hailstorm::Cli::CmdExecutor do
  before(:each) do
    middleware = Hailstorm.application
    project = mock(Hailstorm::Model::Project).as_null_object
    @app = Hailstorm::Cli::CmdExecutor.new(middleware, project)
  end

  context '#interpret_execute' do
    it 'should call interpreted command method on template' do
      @app.stub!(:command_execution_template).and_return(mock(Hailstorm::Middleware::CommandExecutionTemplate))
      @app.command_execution_template.should_receive(:start)
      @app.interpret_execute('start')
    end

    context "'help' command" do
      it 'should call help on self' do
        @app.should_receive(:help)
        @app.interpret_execute('help')
      end
      it 'should call help with additional arguments' do
        @app.should_receive(:help).with('start')
        @app.interpret_execute('help start')
      end
    end

    context "'show' command" do
      it 'should call show on self' do
        @app.should_receive(:show)
        @app.interpret_execute('show')
      end
    end
  end

  context '#help' do
    before(:each) do
      @orig_help_doc = @app.help_doc(File.expand_path('../../../templates/cli/help_docs.yml', __FILE__))
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

  context '#execute_method_args' do
    it 'should call view_renderer.render_results' do
      @app.command_execution_template.stub!(:results).and_return([[], :show])
      @app.view_renderer.should_receive(:render_results).and_return(nil)
      @app.interpret_execute('results')
    end
    it 'should call view_renderer.render_setup' do
      @app.command_execution_template.stub!(:setup)
      @app.view_renderer.should_receive(:render_setup).and_return(nil)
      @app.interpret_execute('setup')
    end
    it 'should call view_renderer.render_status' do
      @app.command_execution_template.stub!(:status).and_return(nil)
      @app.view_renderer.should_receive(:render_status)
      @app.interpret_execute('status')
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
      @app.stub!(:project).and_return(mock_project)
    end
    it 'should show active by default' do
      @app.view_renderer.should_receive(:render_show).with do |_q, show_active, what|
        expect(show_active).to be_true
        expect(what).to be == :active
      end
      @app.show
    end
    it 'show jmeter all' do
      @app.view_renderer.should_receive(:render_show).with do |_q, show_active, what|
        expect(show_active).to be_true
        expect(what).to be == :jmeter
      end
      @app.show('jmeter')
    end
    it 'show all' do
      @app.view_renderer.should_receive(:render_show).with do |_q, show_active, what|
        expect(show_active).to be_false
        expect(what).to be == :all
      end
      @app.show('all')
    end
  end
end
