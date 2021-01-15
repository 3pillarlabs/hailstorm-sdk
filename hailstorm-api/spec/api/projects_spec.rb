# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'api/projects'

require 'hailstorm/model/project'
require 'hailstorm/model/jmeter_plan'
require 'hailstorm/model/execution_cycle'
require 'hailstorm/model/cluster'
require 'hailstorm/model/target_host'
require 'hailstorm/exceptions'

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

      execution_cycle = Hailstorm::Model::ExecutionCycle.new(project: project,
                                                             status: Hailstorm::Model::ExecutionCycle::States::STARTED,
                                                             started_at: Time.now - 15.minutes,
                                                             threads_count: 50)

      allow_any_instance_of(Hailstorm::Model::Project).to receive(:current_execution_cycle).and_return(execution_cycle)

      last_execution_cycle = Hailstorm::Model::ExecutionCycle.new(
        project: project,
        status: Hailstorm::Model::ExecutionCycle::States::STOPPED,
        started_at: Time.now - 60.minutes,
        stopped_at: Time.now - 30.minutes,
        threads_count: 30
      )

      allow(last_execution_cycle).to receive(:avg_90_percentile).and_return(678.45)
      allow(last_execution_cycle).to receive(:avg_tps).and_return(14.56)
      allow_any_instance_of(Hailstorm::Model::Project).to receive_message_chain(
        :execution_cycles, :where, :not, :order, :limit
      ).and_return([last_execution_cycle])

      jmeter_plan = Hailstorm::Model::JmeterPlan.new(
        project: project,
        test_plan_name: 'a',
        content_hash: 'a',
        properties: '{}',
        latest_threads_count: 50
      )

      allow(jmeter_plan).to receive(:loop_forever?).and_return(false)
      allow_any_instance_of(Hailstorm::Model::Project).to receive_message_chain(:jmeter_plans,
                                                                                :all).and_return([jmeter_plan])
      allow_any_instance_of(Hailstorm::Model::Project).to receive_message_chain(:jmeter_plans,
                                                                                :count).and_return(1)

      @browser.get('/projects')
      expect(@browser.last_response).to be_ok
      list = JSON.parse(@browser.last_response.body)
      expect(list.size).to eq(1)
      first = list[0]
      project_keys = %w[id code title running autoStop incomplete currentExecutionCycle lastExecutionCycle live]
      expect(first.keys.sort).to eq(project_keys.sort)
      expect(first['currentExecutionCycle'].keys.sort).to eq(%w[id projectId startedAt threadsCount status].sort)
      execution_cycle_keys = %w[id projectId startedAt threadsCount stoppedAt status responseTime throughput]
      expect(first['lastExecutionCycle'].keys.sort).to eq(execution_cycle_keys.sort)
    end
  end

  context 'POST /projects' do
    it 'should create a project' do
      params = { title: 'Hailstorm Priming' }
      @browser.post('/projects', JSON.dump(params))
      expect(@browser.last_response).to be_ok
      entity = JSON.parse(@browser.last_response.body).symbolize_keys
      expect(entity[:id]).to_not be_blank
      expect(Hailstorm::Model::Project.first.title).to eq(params[:title])
    end
  end

  context 'PATCH /projects/:id' do
    context 'with "action" param ' do
      before(:each) do
        @project = Hailstorm::Model::Project.create!(project_code: 'acme_priming')
        ProjectConfiguration.create!(
          project_id: @project.id,
          stringified_config: deep_encode(Hailstorm::Support::Configuration.new)
        )
      end

      context 'action=terminate' do
        it 'should terminate the setup' do
          Hailstorm::Model::ExecutionCycle.create!(
            project: @project,
            status: Hailstorm::Model::ExecutionCycle::States::STARTED,
            started_at: Time.now - 60.minutes,
            threads_count: 30
          )

          allow(Hailstorm::Model::Cluster).to receive(:terminate)
          allow(Hailstorm::Model::TargetHost).to receive(:terminate)
          @browser.patch("/projects/#{@project.id}", JSON.dump({ action: 'terminate' }))
          expect(@browser.last_response).to be_successful
          status = Hailstorm::Model::ExecutionCycle.first.status
          expect(status).to eq(Hailstorm::Model::ExecutionCycle::States::TERMINATED)
        end
      end

      context 'action=start' do
        it 'should invoke action on model delegate' do
          @project.update_column(:serial_version, 'a')
          allow_any_instance_of(Hailstorm::Model::Project).to receive(:start)
          @browser.patch("/projects/#{@project.id}", JSON.dump({ action: 'start' }))
          expect(@browser.last_response).to be_successful
        end
      end

      context 'action=stop' do
        it 'should invoke action on model delegate' do
          allow_any_instance_of(Hailstorm::Model::Project).to receive(:stop)
          @browser.patch("/projects/#{@project.id}", JSON.dump({ action: 'stop' }))
          expect(@browser.last_response).to be_successful
        end
      end

      context 'action=abort' do
        it 'should invoke action on model delegate' do
          allow_any_instance_of(Hailstorm::Model::Project).to receive(:stop)
          @browser.patch("/projects/#{@project.id}", JSON.dump({ action: 'abort' }))
          expect(@browser.last_response).to be_successful
        end
      end

      context 'unknown action' do
        it 'should return 422 status' do
          allow_any_instance_of(Hailstorm::Model::Project).to receive(:stop)
          @browser.patch("/projects/#{@project.id}", JSON.dump({ action: 'random' }))
          expect(@browser.last_response.status).to be == 422
        end
      end

      context Hailstorm::ThreadJoinException do
        it 'should return 500 status if operation is not retryable' do
          thread_exception = Hailstorm::ThreadJoinException.new([StandardError.new('mock nested error')])
          allow_any_instance_of(Hailstorm::Model::Project).to receive(:stop).and_raise(thread_exception)
          @browser.patch("/projects/#{@project.id}", JSON.dump({ action: 'stop' }))
          expect(@browser.last_response).to be_server_error
        end

        it 'should return 503 status if operation should be tried again' do
          temporary_error = Hailstorm::AgentCreationFailure.new('mock nested error')
          thread_exception = Hailstorm::ThreadJoinException.new([temporary_error])
          allow_any_instance_of(Hailstorm::Model::Project).to receive(:start).and_raise(thread_exception)
          @browser.patch("/projects/#{@project.id}", JSON.dump({ action: 'start' }))
          expect(@browser.last_response.status).to be == 503
        end
      end
    end

    context 'with "title" param' do
      before(:each) do
        @project = Hailstorm::Model::Project.create!(project_code: 'acme_priming', title: 'Acme Priming')
      end

      it 'should update the project title but not the title' do
        @browser.patch("/projects/#{@project.id}", JSON.dump({ title: 'Acme Priming 32' }))
        expect(@browser.last_response).to be_successful
        @project.reload
        expect(@project.title).to be == 'Acme Priming 32'
        expect(@project.project_code).to be == 'acme_priming'
      end
    end
  end

  context 'GET /projects/:id' do
    it 'should get project attributes' do
      project = Hailstorm::Model::Project.create!(title: 'Acme Priming', project_code: 'acme_priming')
      @browser.get("/projects/#{project.id}")
      expect(@browser.last_response).to be_successful
      attrs = JSON.parse(@browser.last_response.body)
      expect(attrs.keys).to include('code')
      expect(attrs.keys).to include('id')
    end

    it 'should return 404 if project is not found' do
      allow(Hailstorm::Model::Project).to receive(:find).and_raise(ActiveRecord::RecordNotFound.new('mock error'))
      @browser.get('/projects/404')
      expect(@browser.last_response).to be_not_found
    end
  end

  context 'DELETE /projects/:id' do
    before(:each) do
      @project = Hailstorm::Model::Project.create!(title: 'Acme Priming', project_code: 'acme_priming')
      allow(Hailstorm.fs).to receive(:purge_project)
    end

    context 'existing ProjectConfiguration' do
      it 'should destroy the project' do
        ProjectConfiguration.create!(
          project: @project,
          stringified_config: deep_encode(Hailstorm::Support::Configuration.new)
        )

        @browser.delete("/projects/#{@project.id}")
        expect(@browser.last_response).to be_successful
        expect { Hailstorm::Model::Project.find(@project.id) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'no ProjectConfiguration' do
      it 'should destroy the project' do
        @browser.delete("/projects/#{@project.id}")
        expect(@browser.last_response).to be_successful
        expect { Hailstorm::Model::Project.find(@project.id) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    it 'should purge project resources on file server' do
      expect(Hailstorm.fs).to receive(:purge_project)
      @browser.delete("/projects/#{@project.id}")
    end
  end
end
