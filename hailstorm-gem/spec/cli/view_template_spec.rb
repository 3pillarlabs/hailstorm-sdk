require 'spec_helper'
require 'hailstorm/cli/view_template'
require 'hailstorm/model/nmon'
require 'hailstorm/model/jmeter_plan'
require 'hailstorm/model/project'
require 'hailstorm/model/master_agent'
require 'hailstorm/model/amazon_cloud'
require 'hailstorm/model/cluster'
require 'hailstorm/model/execution_cycle'
require 'hailstorm/model/client_stat'

describe Hailstorm::Cli::ViewTemplate do
  before(:each) do
    @app = Hailstorm::Cli::ViewTemplate.new
    @project = Hailstorm::Model::Project.create!(project_code: 'view_template_spec')
    @test_plan = Hailstorm::Model::JmeterPlan.create!(active: false, project: @project,
                                                      test_plan_name: 'view_template_spec', content_hash: 'A')
    @test_plan.update_attribute(:properties, {NumUsers: 100}.to_json)
    @test_plan.update_column(:active, true)
  end

  context '#render_jmeter_plans' do
    it 'should not raise_error' do
      expect { @app.render_jmeter_plans([@test_plan], true) }.to_not raise_error
    end
  end

  context '#render_load_agents' do
    it 'should not raise_error' do
      amz = Hailstorm::Model::AmazonCloud.create!(project: @project, access_key: 'A', secret_key: 'A')
      la = Hailstorm::Model::MasterAgent.create!(clusterable_id: amz.id, clusterable_type: amz.class.name,
                                                 jmeter_plan: @test_plan, active: false,
                                                 public_ip_address: '8.8.8.8', jmeter_pid: 9123)
      la.update_column(:active, true)
      cluster = Hailstorm::Model::Cluster.create!(project: @project,
                                                  cluster_type: amz.class.name,
                                                  clusterable_id: amz.id)
      amz.update_column(:active, true)
      expect { @app.render_load_agents([cluster], true) }.to_not raise_error
    end
  end

  context '#render_target_hosts' do
    it 'should not raise_error' do
      target_host = Hailstorm::Model::Nmon.create!(project: @project, host_name: 'app.de.mon',
                                                   role_name: 'server', executable_pid: 2345)
      expect { @app.render_target_hosts([target_host], true) }.to_not raise_error
    end
  end

  context '#render_results_show' do
    before(:each) do
      amz = Hailstorm::Model::AmazonCloud.create!(project: @project, access_key: 'A', secret_key: 'A')
      started_at, stopped_at = [Time.now - 30.minutes, Time.now]
      execution_cycle = Hailstorm::Model::ExecutionCycle.create!(project: @project,
                                                                 status: Hailstorm::Model::ExecutionCycle::States::STOPPED,
                                                                 started_at: started_at, stopped_at: stopped_at)
      Hailstorm::Model::ClientStat.create!(execution_cycle: execution_cycle, jmeter_plan: @test_plan,
                                           clusterable_id: amz.id, clusterable_type: amz.class.name,
                                           threads_count: 10000, aggregate_ninety_percentile: 789.56,
                                           aggregate_response_throughput: 878.23932,
                                           last_sample_at: stopped_at - 10.seconds)

      @show_data = [ execution_cycle ]
    end
    context 'format not nil' do
      it 'should convert data to json' do
        expect(@app.render_results_show(@show_data, :json).tap { |text| puts text }).to match(/^\[/)
      end
    end
    context 'nil format' do
      it 'should convert data to tabular format' do
        expect(@app.render_results_show(@show_data).tap { |text| puts text }).to match(/90 %tile/)
      end
    end
  end

  context '#render_running_agents' do
    before(:each) do
      amz = Hailstorm::Model::AmazonCloud.create!(project: @project, access_key: 'A', secret_key: 'A')
      la = Hailstorm::Model::MasterAgent.create!(clusterable_id: amz.id, clusterable_type: amz.class.name,
                                                 jmeter_plan: @test_plan, active: false,
                                                 public_ip_address: '8.8.8.8', jmeter_pid: 9123)
      la.update_column(:active, true)
      @running_agents = [ la ]
    end
    context 'format == json' do
      it 'should convert data to json' do
        expect(@app.render_running_agents(@running_agents, :json)).to match(/^\[/)
      end
    end
    context 'format != json' do
      it 'should convert data to tabular format' do
        expect(@app.render_running_agents(@running_agents)).to match(/PID/)
      end
    end
  end
end
