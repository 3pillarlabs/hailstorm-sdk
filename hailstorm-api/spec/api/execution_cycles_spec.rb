# frozen_string_literal: true

require 'spec_helper'
require 'api/execution_cycles'
require 'hailstorm/model/amazon_cloud'
require 'hailstorm/model/jmeter_plan'
require 'hailstorm/model/master_agent'
require 'hailstorm/exceptions'

describe 'api/execution_cycles' do
  before(:each) do
    @browser = Rack::Test::Session.new(Sinatra::Application)
  end

  context 'GET /projects/:id/execution_cycles' do
    it 'should list execution cycles of a project' do
      project = Hailstorm::Model::Project.create!(project_code: File.strip_ext(File.basename(__FILE__)))
      epoch_time = Time.now
      Hailstorm::Model::ExecutionCycle.create!(
        project_id: project.id,
        status: Hailstorm::Model::ExecutionCycle::States::STOPPED,
        threads_count: 10,
        started_at: epoch_time.ago(120.minutes),
        stopped_at: epoch_time.ago(105.minutes)
      )

      Hailstorm::Model::ExecutionCycle.create!(
        project_id: project.id,
        status: Hailstorm::Model::ExecutionCycle::States::STOPPED,
        threads_count: 20,
        started_at: epoch_time.ago(100.minutes),
        stopped_at: epoch_time.ago(85.minutes)
      )

      Hailstorm::Model::ExecutionCycle.create!(
        project_id: project.id,
        status: Hailstorm::Model::ExecutionCycle::States::ABORTED,
        threads_count: 30,
        started_at: epoch_time.ago(90.minutes)
      )

      Hailstorm::Model::ExecutionCycle.create!(
        project_id: project.id,
        status: Hailstorm::Model::ExecutionCycle::States::ABORTED,
        threads_count: 30,
        started_at: epoch_time.ago(80.minutes),
        stopped_at: epoch_time.ago(75.minutes)
      )

      Hailstorm::Model::ExecutionCycle.create!(
        project_id: project.id,
        status: Hailstorm::Model::ExecutionCycle::States::STARTED,
        threads_count: 30,
        started_at: epoch_time.ago(70.minutes)
      )

      allow_any_instance_of(Hailstorm::Model::ExecutionCycle).to receive(:avg_90_percentile).and_return(234.56)
      allow_any_instance_of(Hailstorm::Model::ExecutionCycle).to receive(:avg_tps).and_return(23.5)

      @browser.get("/projects/#{project.id}/execution_cycles")
      expect(@browser.last_response).to be_ok
      res = JSON.parse(@browser.last_response.body)
      expect(res.size).to eq(3)
      expect(res[0]['status']).to eq(Hailstorm::Model::ExecutionCycle::States::STARTED.to_s)
      expect(res[1]['threadsCount']).to eq(20)
      expect(res[2]['threadsCount']).to eq(10)
      resp_keys = %w[id projectId startedAt stoppedAt status threadsCount responseTime throughput]
      expect(res[2].keys.sort).to eq(resp_keys.sort)
    end

    it 'should be empty when there are no execution_cycles' do
      project = Hailstorm::Model::Project.create!(project_code: File.strip_ext(File.basename(__FILE__)))
      @browser.get("/projects/#{project.id}/execution_cycles")
      expect(@browser.last_response).to be_ok
      res = JSON.parse(@browser.last_response.body)
      expect(res.size).to eq(0)
    end
  end

  context 'GET /projects/:project_id/execution_cycles/current' do
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
      allow_any_instance_of(Hailstorm::Model::MasterAgent).to receive(:check_status).and_return(@master_agent)
      @browser.get("/projects/#{@project.id}/execution_cycles/current")
      expect(@browser.last_response).to be_ok
      res = JSON.parse(@browser.last_response.body)
      expect(res['noRunningTests']).to eq(false)
    end

    it 'should set noRunningTests in response to true if there are no tests running' do
      allow_any_instance_of(Hailstorm::Model::MasterAgent).to receive(:check_status).and_return(nil)
      @browser.get("/projects/#{@project.id}/execution_cycles/current")
      expect(@browser.last_response).to be_ok
      res = JSON.parse(@browser.last_response.body)
      expect(res['noRunningTests']).to eq(true)
    end

    it 'should return internal server error if check for status fails' do
      exception = Hailstorm::ThreadJoinException.new(StandardError.new('mock thread exception'))
      allow_any_instance_of(Hailstorm::Model::MasterAgent).to receive(:check_status).and_raise(exception)

      @browser.get("/projects/#{@project.id}/execution_cycles/current")
      expect(@browser.last_response.status).to be == 500
    end
  end

  context 'PATCH /projects/:projectId/execution_cycles/:id' do
    it 'should exclude an execution cycle' do
      project = Hailstorm::Model::Project.create!(project_code: 'execution_cycles_spec')
      execution_cycle = Hailstorm::Model::ExecutionCycle.create!(
        project_id: project.id,
        status: Hailstorm::Model::ExecutionCycle::States::STOPPED,
        started_at: Time.now.ago(70.minutes),
        stopped_at: Time.now.ago(60.minutes),
        threads_count: 30
      )

      @browser.patch("/projects/#{project.id}/execution_cycles/#{execution_cycle.id}",
                     JSON.dump({ status: 'excluded' }))
      expect(@browser.last_response).to be_ok
      res = JSON.parse(@browser.last_response.body)
      expect(res['status']).to eq(Hailstorm::Model::ExecutionCycle::States::EXCLUDED.to_s)
    end

    it 'should include back an execution cycle' do
      project = Hailstorm::Model::Project.create!(project_code: 'execution_cycles_spec')
      execution_cycle = Hailstorm::Model::ExecutionCycle.create!(
        project_id: project.id,
        status: Hailstorm::Model::ExecutionCycle::States::EXCLUDED,
        started_at: Time.now.ago(70.minutes),
        stopped_at: Time.now.ago(60.minutes),
        threads_count: 30
      )

      @browser.patch("/projects/#{project.id}/execution_cycles/#{execution_cycle.id}",
                     JSON.dump({ status: 'stopped' }))
      expect(@browser.last_response).to be_ok
      res = JSON.parse(@browser.last_response.body)
      expect(res['status']).to eq(Hailstorm::Model::ExecutionCycle::States::STOPPED.to_s)
    end

    it 'should return unprocessable entity status if status is not known' do
      project = Hailstorm::Model::Project.create!(project_code: 'execution_cycles_spec')
      execution_cycle = Hailstorm::Model::ExecutionCycle.create!(
        project_id: project.id,
        status: Hailstorm::Model::ExecutionCycle::States::EXCLUDED,
        started_at: Time.now.ago(70.minutes),
        stopped_at: Time.now.ago(60.minutes),
        threads_count: 30
      )

      @browser.patch("/projects/#{project.id}/execution_cycles/#{execution_cycle.id}",
                     JSON.dump({ status: 'random' }))
      expect(@browser.last_response.status).to be == 422
    end
  end
end
