require 'spec_helper'
require 'hailstorm/cli/view_template'
require 'hailstorm/model/nmon'

describe Hailstorm::Cli::ViewTemplate do
  before(:each) do
    @app = Hailstorm::Cli::ViewTemplate.new
  end

  context '#render_jmeter_plans' do
    it 'should not raise_error' do
      test_plans = [double('Test Plan', test_plan_name: 'spec', properties_map: { num_threads: 100 })]
      expect { @app.render_jmeter_plans(test_plans, true) }.to_not raise_error
    end
  end

  context '#render_load_agents' do
    it 'should not raise_error' do
      load_agent_double = double('Load Agent',
                                 jmeter_plan: double('Test Plan', test_plan_name: 'spec'),
                                 master?: true,
                                 public_ip_address: '8.8.8.8',
                                 jmeter_pid: 9123)
      clusterable = double('Clusterable',
                           slug: 'amazon-us-east-1',
                           load_agents: double('Load Agent Queryable',
                                               active: [load_agent_double]))
      cluster = double('Cluster', cluster_code: 'amazon', clusterables: [clusterable])
      expect { @app.render_load_agents([cluster], true) }.to_not raise_error
    end
  end

  context '#render_target_hosts' do
    it 'should not raise_error' do
      target_host = double('TargetHost',
                           role_name: 'server',
                           host_name: 'app.de.mon',
                           class: Hailstorm::Model::Nmon,
                           executable_pid: 2345)
      expect { @app.render_target_hosts([target_host], true) }.to_not raise_error
    end
  end

  context '#render_results_show' do
    before(:each) do
      @show_data = [double('execution_cycle#1',
                           id: 123,
                           total_threads_count: 10000,
                           avg_90_percentile: 789.56,
                           avg_tps: 878.23932,
                           formatted_started_at: '2018-01-01 16:00:00',
                           formatted_stopped_at: '2018-01-01 16:30:00')]
    end
    context 'format not nil' do
      it 'should convert data to json' do
        expect(@app.render_results_show(@show_data, :json)).to match(/^\[/)
      end
    end
    context 'nil format' do
      it 'should convert data to tabular format' do
        expect(@app.render_results_show(@show_data)).to match(/90 %tile/)
      end
    end
  end

  context '#render_running_agents' do
    before(:each) do
      cluster_attrs = { slug: 'rockstar' }
      agent_attrs = { public_ip_address: '182.45.23.45', jmeter_pid: 23456 }
      agent_attrs[:to_json] = cluster_attrs.merge(agent_attrs)
      @running_agents = [double('running_agent#1',
                                { clusterable: double('Clusterable#1', cluster_attrs) }.merge(agent_attrs))]
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
