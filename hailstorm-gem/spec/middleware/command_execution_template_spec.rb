require 'spec_helper'
require 'hailstorm/middleware/command_execution_template'
require 'hailstorm/model/project'
require 'hailstorm/model/jmeter_plan'
require 'hailstorm/model/amazon_cloud'
require 'hailstorm/model/cluster'
require 'hailstorm/model/execution_cycle'
require 'hailstorm/model/master_agent'
require 'hailstorm/support/configuration'

describe Hailstorm::Middleware::CommandExecutionTemplate do

  before(:each) do
    mock_delegate = mock(Hailstorm::Model::Project)
    config = Hailstorm::Support::Configuration.new
    @app = Hailstorm::Middleware::CommandExecutionTemplate.new(mock_delegate, config)
  end

  %i[setup start stop abort terminate results].each do |cmd|
    context "##{cmd}" do
      it 'should pass through to :model_delegate' do
        @app.model_delegate.should_receive(cmd)
        @app.send(cmd)
      end
    end
  end

  context '#results' do
    it 'should return data, operation and format' do
      @app.model_delegate.stub!(:results).and_return([])
      seq = ['foo.jtl', {'jmeter' => '1', 'cluster' => '2'}]
      expect(@app.results(false, 'json', :show, seq)).to be == [[], :show, 'json']
    end

    context 'with extract_last == true' do
      before(:each) do
        r1 = { id: 3, total_threads_count: 100, avg_90_percentile: 1300.43, avg_tps: 2000.345,
               formatted_started_at: '2018-01-01 14:10:00', formatted_stopped_at: '2018-01-01 14:25:00' }
        r2 = r1.clone
        r2[:id] = 4
        @data = [ OpenStruct.new(r1), OpenStruct.new(r2) ]
        @app.model_delegate.stub!(:results).and_return(@data)
      end
      it 'should return only the last data' do
        expect(@app.results(true, nil, :show)[0]).to be == [@data.last]
      end
    end
  end

  context '#purge' do
    before(:each) do
      @mock_ex_cycle = mock(Hailstorm::Model::ExecutionCycle)
      @app.model_delegate.stub!(:execution_cycles).and_return([@mock_ex_cycle])
    end
    it 'should destroy all execution_cycles' do
      @mock_ex_cycle.should_receive(:destroy)
      @app.purge
    end
    context 'tests' do
      it 'should destroy all execution_cycles' do
        @mock_ex_cycle.should_receive(:destroy)
        @app.purge('tests')
      end
    end
    context 'clusters' do
      it 'should purge_clusters' do
        @app.model_delegate.should_receive(:purge_clusters)
        @app.purge('clusters')
      end
    end
    context 'all' do
      it 'should destroy mock_delegate' do
        @app.model_delegate.should_receive(:destroy)
        @app.purge('all')
      end
    end
  end

  context '#status' do
    context 'current_execution_cycle is nil' do
      it 'should not raise_error' do
        @app.model_delegate.stub!(:current_execution_cycle).and_return(nil)
        expect { @app.status }.to_not raise_error
      end
    end
    context 'current_execution_cycle is truthy' do
      before(:each) do
        @app.model_delegate.stub!(:current_execution_cycle).and_return(true)
      end
      context 'no running agents' do
        before(:each) do
          @app.model_delegate.stub!(:check_status).and_return([])
        end
        it 'should not raise_error' do
          expect { @app.status }.to_not raise_error
        end
        context 'json format' do
          it 'should not raise_error' do
            expect { @app.status('json') }.to_not raise_error
          end
        end
      end
      context 'with running agents' do
        before(:each) do
          project = Hailstorm::Model::Project.create!(project_code: 'command_execution_template_spec')
          test_plan = Hailstorm::Model::JmeterPlan.create!(active: false, project: project,
                                                           test_plan_name: 'view_template_spec', content_hash: 'A')
          test_plan.update_attribute(:properties, {NumUsers: 100}.to_json)
          test_plan.update_column(:active, true)
          amz = Hailstorm::Model::AmazonCloud.create!(project: project, access_key: 'A', secret_key: 'A')
          Hailstorm::Model::Cluster.create!(project: project, cluster_type: amz.class.name, clusterable_id: amz.id)
          amz.update_column(:active, true)
          Hailstorm::Model::ExecutionCycle.create!(project: project,
                                                   status: Hailstorm::Model::ExecutionCycle::States::STARTED,
                                                   started_at: Time.now)
          @master_agent = Hailstorm::Model::MasterAgent.create!(clusterable_id: amz.id, clusterable_type: amz.class.name,
                                                                jmeter_plan: test_plan, public_ip_address: '8.8.8.8',
                                                                active: false, jmeter_pid: 9364)
          @master_agent.update_column(:active, true)

          @app.stub!(:model_delegate).and_return(project)
          Hailstorm::Model::MasterAgent.any_instance.stub(:check_status)
                                       .and_return(@master_agent)
        end
        it 'should not raise_error' do
          expect { @app.status }.to_not raise_error
        end
        context 'json format' do
          it 'should not raise_error' do
            agents, format = @app.status('json')
            expect(agents).to be_eql([@master_agent])
            expect(format).to be == 'json'
          end
        end
      end
    end
  end
end
