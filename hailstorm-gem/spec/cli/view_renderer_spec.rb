require 'spec_helper'
require 'hailstorm/cli/view_renderer'
require 'hailstorm/model/project'

describe Hailstorm::Cli::ViewRenderer do
  before(:each) do
    @app = Hailstorm::Cli::ViewRenderer.new(mock(Hailstorm::Model::Project))
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

  context '#render_show' do
    before(:each) do
      active_queryable = double('Queryable Active', natural_order: [])
      queryable = double('Queryable', active: active_queryable, natural_order: [])
      %i[jmeter_plans clusters target_hosts].each do |sym|
        @app.project.stub!(sym).and_return(queryable)
      end
      @query_map = { jmeter_plans: [], clusters: [], target_hosts: [] }
    end
    it 'should show everything active' do
      @app.view_template.should_receive(:render_jmeter_plans) { |_q, flag| expect(flag).to be_true }
      @app.view_template.should_receive(:render_load_agents) { |_q, flag| expect(flag).to be_true }
      @app.view_template.should_receive(:render_target_hosts) { |_q, flag| expect(flag).to be_true }
      @app.render_show(@query_map, true, :active)
    end
    context 'jmeter' do
      it 'should show active jmeter' do
        @app.view_template.should_receive(:render_jmeter_plans) { |_q, flag| expect(flag).to be_true }
        @app.view_template.should_not_receive(:render_load_agents)
        @app.view_template.should_not_receive(:render_target_hosts)
        @app.render_show(@query_map, true,:jmeter)
      end
      context 'all' do
        it 'should show all jmeter' do
          @app.view_template.should_receive(:render_jmeter_plans) { |_q, flag| expect(flag).to be_false }
          @app.view_template.should_not_receive(:render_load_agents)
          @app.view_template.should_not_receive(:render_target_hosts)
          @app.render_show(@query_map, false, :jmeter)
        end
      end
    end
    context 'cluster' do
      it 'should show active cluster' do
        @app.view_template.should_receive(:render_load_agents) { |_q, flag| expect(flag).to be_true }
        @app.view_template.should_not_receive(:render_jmeter_plans)
        @app.view_template.should_not_receive(:render_target_hosts)
        @app.render_show(@query_map, true, :cluster)
      end
      context 'all' do
        it 'should show all cluster' do
          @app.view_template.should_receive(:render_load_agents) { |_q, flag| expect(flag).to be_false }
          @app.view_template.should_not_receive(:render_jmeter_plans)
          @app.view_template.should_not_receive(:render_target_hosts)
          @app.render_show(@query_map, false, :cluster)
        end
      end
    end
    context 'monitor' do
      it 'should show active monitor' do
        @app.view_template.should_receive(:render_target_hosts) { |_q, flag| expect(flag).to be_true }
        @app.view_template.should_not_receive(:render_jmeter_plans)
        @app.view_template.should_not_receive(:render_load_agents)
        @app.render_show(@query_map, true, :monitor)
      end
      context 'all' do
        it 'should show all monitor' do
          @app.view_template.should_receive(:render_target_hosts) { |_q, flag| expect(flag).to be_false }
          @app.view_template.should_not_receive(:render_jmeter_plans)
          @app.view_template.should_not_receive(:render_load_agents)
          @app.render_show(@query_map, false, :monitor)
        end
      end
    end
    context 'active' do
      it 'should show everything active' do
        @app.view_template.should_receive(:render_jmeter_plans) { |_q, flag| expect(flag).to be_true }
        @app.view_template.should_receive(:render_load_agents) { |_q, flag| expect(flag).to be_true }
        @app.view_template.should_receive(:render_target_hosts) { |_q, flag| expect(flag).to be_true }
        @app.render_show(@query_map, true, :active)
      end
    end
    context 'all' do
      it 'should show everything including inactive' do
        @app.view_template.should_receive(:render_jmeter_plans) { |_q, flag| expect(flag).to be_false }
        @app.view_template.should_receive(:render_load_agents) { |_q, flag| expect(flag).to be_false }
        @app.view_template.should_receive(:render_target_hosts) { |_q, flag| expect(flag).to be_false }
        @app.render_show(@query_map, false, :all)
      end
    end
  end

  context '#render_setup' do
    before(:each) do
      @app.project.stub_chain(:jmeter_plans, :active).and_return([])
      @app.project.stub!(:clusters).and_return([])
      @app.project.stub_chain(:target_hosts, :active, :natural_order).and_return([])
    end
    it 'should render jmeter plans' do
      @app.view_template.should_receive(:render_jmeter_plans)
      @app.render_setup
    end
    it 'should render defaults' do
      @app.should_receive(:render_default)
      @app.render_setup
    end
  end
end
