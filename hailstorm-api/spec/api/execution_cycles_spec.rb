require 'spec_helper'
require 'api/execution_cycles'
require 'hailstorm/model/amazon_cloud'
require 'hailstorm/model/jmeter_plan'
require 'hailstorm/model/master_agent'

describe 'api/execution_cycles' do
  before(:each) do
    @browser = Rack::Test::Session.new(Sinatra::Application)
  end

  context '/projects/:id/execution_cycles' do
    it 'should list execution cycles of a project' do
      project = Hailstorm::Model::Project.create!(project_code: File.strip_ext(File.basename(__FILE__)))
      epoch_time = Time.now
      Hailstorm::Model::ExecutionCycle.create!(
        project_id: project.id,
        status: Hailstorm::Model::ExecutionCycle::States::STOPPED,
        started_at: epoch_time.ago(120.minutes),
        stopped_at: epoch_time.ago(105.minutes),
        threads_count: 10
      )

      Hailstorm::Model::ExecutionCycle.create!(
        project_id: project.id,
        status: Hailstorm::Model::ExecutionCycle::States::STOPPED,
        started_at: epoch_time.ago(100.minutes),
        stopped_at: epoch_time.ago(85.minutes),
        threads_count: 20
      )

      Hailstorm::Model::ExecutionCycle.create!(
        project_id: project.id,
        status: Hailstorm::Model::ExecutionCycle::States::ABORTED,
        started_at: epoch_time.ago(90.minutes),
        threads_count: 30
      )

      Hailstorm::Model::ExecutionCycle.create!(
        project_id: project.id,
        status: Hailstorm::Model::ExecutionCycle::States::ABORTED,
        started_at: epoch_time.ago(80.minutes),
        stopped_at: epoch_time.ago(75.minutes),
        threads_count: 30
      )

      Hailstorm::Model::ExecutionCycle.create!(
        project_id: project.id,
        status: Hailstorm::Model::ExecutionCycle::States::STARTED,
        started_at: epoch_time.ago(70.minutes),
        threads_count: 30
      )

      Hailstorm::Model::ExecutionCycle.any_instance.stub(:avg_90_percentile).and_return(234.56)
      Hailstorm::Model::ExecutionCycle.any_instance.stub(:avg_tps).and_return(23.5)

      @browser.get("/projects/#{project.id}/execution_cycles")
      expect(@browser.last_response).to be_ok
      res = JSON.parse(@browser.last_response.body)
      expect(res.size).to eq(3)
      expect(res[0]['status']).to eq(Hailstorm::Model::ExecutionCycle::States::STARTED.to_s)
      expect(res[1]['threadsCount']).to eq(20)
      expect(res[2]['threadsCount']).to eq(10)
      expect(res[2].keys.sort).to eq(%w[id projectId startedAt stoppedAt status threadsCount responseTime throughput].sort)
    end

    it 'should be empty when there are no execution_cycles' do
      project = Hailstorm::Model::Project.create!(project_code: File.strip_ext(File.basename(__FILE__)))
      @browser.get("/projects/#{project.id}/execution_cycles")
      expect(@browser.last_response).to be_ok
      res = JSON.parse(@browser.last_response.body)
      expect(res.size).to eq(0)
    end
  end

  context '/projects/:project_id/execution_cycles/current' do
    before(:each) do
      @project = Hailstorm::Model::Project.create!(project_code: File.strip_ext(File.basename(__FILE__)))

      Hailstorm::Model::ExecutionCycle.create!(
        project_id: @project.id,
        status: Hailstorm::Model::ExecutionCycle::States::STARTED,
        started_at: Time.now.ago(70.minutes),
        threads_count: 30
      )

      amz_cloud = Hailstorm::Model::AmazonCloud.create!(
        project_id: @project.id,
        access_key: 'A',
        secret_key: 's',
        active: false
      )

      amz_cloud.update_column(:active, true)

      Hailstorm::Model::Cluster.create!(
        project_id: @project.id,
        cluster_type: amz_cloud.class.name,
        clusterable_id: amz_cloud.id
      )

      jmeter_plan = Hailstorm::Model::JmeterPlan.create!(
        project_id: @project.id,
        test_plan_name: 'a',
        content_hash: 'A',
        active: false,
        properties: '{}',
        latest_threads_count: 30
      )

      jmeter_plan.update_column(:active, true)
      @master_agent = Hailstorm::Model::MasterAgent.create!(
        clusterable_id: amz_cloud.id,
        clusterable_type: amz_cloud.class.name,
        jmeter_plan_id: jmeter_plan.id,
        public_ip_address: '23.34.56.23',
        private_ip_address: '10.0.0.10',
        active: false,
        jmeter_pid: 234,
        identifier: 'i-234566'
      )

      @master_agent.update_column(:active, true)
    end

    it 'should set noRunningTests in response to false if tests are running' do
      Hailstorm::Model::MasterAgent.any_instance.stub(:check_status).and_return(@master_agent)
      @browser.get("/projects/#{@project.id}/execution_cycles/current")
      expect(@browser.last_response).to be_ok
      res = JSON.parse(@browser.last_response.body)
      expect(res['noRunningTests']).to eq(false)
    end

    it 'should set noRunningTests in response to true if there are no tests running' do
      Hailstorm::Model::MasterAgent.any_instance.stub(:check_status).and_return(nil)
      @browser.get("/projects/#{@project.id}/execution_cycles/current")
      expect(@browser.last_response).to be_ok
      res = JSON.parse(@browser.last_response.body)
      expect(res['noRunningTests']).to eq(true)
    end
  end
end
