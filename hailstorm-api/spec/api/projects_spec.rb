require 'spec_helper'
require 'json'
require 'app/api/projects'

require 'hailstorm/model/project'
require 'hailstorm/model/jmeter_plan'
require 'hailstorm/model/execution_cycle'
require 'hailstorm/model/cluster'
require 'hailstorm/model/target_host'

describe 'api/projects' do
  before(:each) do
    @browser = Rack::Test::Session.new(Sinatra::Application)
  end

  context 'GET /projects' do
    it 'should return empty list of projects' do
      @browser.get('/projects')
      expect(@browser.last_response).to be_ok
      expect(JSON.parse(@browser.last_response.body)).to eq([])
    end

    it 'should list projects with current and last execution_cycle' do
      project = Hailstorm::Model::Project.create!(title: 'Acme Priming', project_code: 'acme_priming')

      Hailstorm::Model::Project
        .any_instance.stub(:current_execution_cycle)
        .and_return(Hailstorm::Model::ExecutionCycle.new(project: project,
                                                         status: Hailstorm::Model::ExecutionCycle::States::STARTED,
                                                         started_at: Time.now - 15.minutes,
                                                         threads_count: 50))

      last_execution_cycle = Hailstorm::Model::ExecutionCycle.new(
        project: project,
        status: Hailstorm::Model::ExecutionCycle::States::STOPPED,
        started_at: Time.now - 60.minutes,
        stopped_at: Time.now - 30.minutes,
        threads_count: 30
      )

      last_execution_cycle.stub!(:avg_90_percentile).and_return(678.45)
      last_execution_cycle.stub!(:avg_tps).and_return(14.56)
      Hailstorm::Model::Project
        .any_instance
        .stub_chain(:execution_cycles, :where, :order, :limit)
        .and_return([last_execution_cycle])

      jmeter_plan = Hailstorm::Model::JmeterPlan.new(
        project: project,
        test_plan_name: 'a',
        content_hash: 'a',
        properties: '{}',
        latest_threads_count: 50
      )

      jmeter_plan.stub!(:loop_forever?).and_return(false)
      Hailstorm::Model::Project
        .any_instance
        .stub_chain(:jmeter_plans, :all)
        .and_return([jmeter_plan])

      Hailstorm::Model::Project
        .any_instance
        .stub_chain(:jmeter_plans, :count)
        .and_return(1)

      @browser.get('/projects')
      expect(@browser.last_response).to be_ok
      list = JSON.parse(@browser.last_response.body)
      expect(list.size).to eq(1)
      first = list[0]
      expect(first.keys.sort).to eq(%W[id code title running autoStop incomplete currentExecutionCycle lastExecutionCycle].sort)
      expect(first['currentExecutionCycle'].keys.sort).to eq(%W[id projectId startedAt threadsCount status].sort)
      expect(first['lastExecutionCycle'].keys.sort).to eq(%W[id projectId startedAt threadsCount stoppedAt status responseTime throughput].sort)
    end
  end

  context 'POST /projects' do
    it 'should create a project' do
      params = {title: 'Hailstorm Priming'}
      @browser.post('/projects', JSON.dump(params))
      expect(@browser.last_response).to be_ok
      entity = JSON.parse(@browser.last_response.body).symbolize_keys
      expect(entity[:id]).to_not be_blank
      expect(Hailstorm::Model::Project.first.title).to eq(params[:title])
    end
  end

  context 'PATCH /projects/:id' do
    context 'action=terminate' do
      it 'should terminate the setup' do
        project = Hailstorm::Model::Project.create!(project_code: 'acme_priming')
        ProjectConfiguration.create!(
          project_id: project.id,
          stringified_config: deep_encode(Hailstorm::Support::Configuration.new)
        )

        Hailstorm::Model::ExecutionCycle.create!(
            project: project,
            status: Hailstorm::Model::ExecutionCycle::States::STARTED,
            started_at: Time.now - 60.minutes,
            threads_count: 30
        )

        Hailstorm::Model::Cluster.stub!(:terminate)
        Hailstorm::Model::TargetHost.stub!(:terminate)
        @browser.patch("/projects/#{project.id}", JSON.dump({action: 'terminate'}))
        expect(@browser.last_response).to be_successful
        expect(Hailstorm::Model::ExecutionCycle.first.status).to eq(Hailstorm::Model::ExecutionCycle::States::TERMINATED.to_s)
      end
    end
  end
end
