require 'spec_helper'
require 'jtl_log_data'
require 'hailstorm/model/execution_cycle'
require 'hailstorm/model/amazon_cloud'
require 'hailstorm/model/data_center'
require 'hailstorm/model/nmon'
require 'client_stats_helper'

describe Hailstorm::Model::ExecutionCycle do

  include ClientStatsHelper

  def generate_execution_cycles(cycle_ids = [])
    cycle_ids.map do |cycle_id|
      execution_cycle = Hailstorm::Model::ExecutionCycle.new
      execution_cycle.started!
      execution_cycle.id = cycle_id

      chart_model = double('ChartModel', getFilePath: '', getWidth: 800, getHeight: 600)

      expect(execution_cycle).to respond_to(:clusters)
      cluster = Hailstorm::Model::AmazonCloud.new
      client_stat = Hailstorm::Model::ClientStat.new
      expect(client_stat).to respond_to(:jmeter_plan)
      jmeter_plan = Hailstorm::Model::JmeterPlan.new
      expect(jmeter_plan).to respond_to(:plan_name)
      allow(jmeter_plan).to receive(:plan_name).and_return('Priming test')
      allow(client_stat).to receive(:jmeter_plan).and_return(jmeter_plan)
      allow(client_stat).to receive(:aggregate_graph).and_return(chart_model)
      expect(cluster).to respond_to(:client_stats)
      allow(cluster).to receive_message_chain(:client_stats, :where).and_return([ client_stat ])
      allow(execution_cycle).to receive(:clusters).and_return([cluster])

      expect(execution_cycle).to respond_to(:target_stats)
      target_stat = Hailstorm::Model::TargetStat.new
      expect(target_stat).to respond_to(:target_host)
      allow(target_stat).to receive(:target_host).and_return(Hailstorm::Model::TargetHost.new)
      allow(target_stat).to receive(:utilization_graph).and_return(chart_model)
      allow(execution_cycle).to receive(:target_stats).and_return([target_stat])
      allow(execution_cycle).to receive(:target_hosts).and_return([target_stat.target_host])
      execution_cycle
    end
  end

  context '.create_report' do
    context 'Execution cycles exist' do
      it 'should build the report' do
        project = Hailstorm::Model::Project.new(project_code: 'execution_cycle_spec')
        builder = Hailstorm::Support::ReportBuilder.new
        expect(builder).to receive(:build)
        cycle_ids = [1, 3, 4]
        allow(Hailstorm::Model::ExecutionCycle).to receive(:execution_cycles_for_report).and_return(generate_execution_cycles(cycle_ids))
        chart_model = double('ChartModel', getFilePath: '', getWidth: 800, getHeight: 600)
        allow_any_instance_of(Hailstorm::Model::ExecutionCycle).to receive(:hits_per_second_graph).and_return(chart_model)
        allow_any_instance_of(Hailstorm::Model::ExecutionCycle).to receive(:active_threads_over_time_graph).and_return(chart_model)
        allow_any_instance_of(Hailstorm::Model::ExecutionCycle).to receive(:throughput_over_time_graph).and_return(chart_model)
        allow(Hailstorm::Model::ExecutionCycle).to receive(:client_comparison_graph).and_return(chart_model)
        allow(Hailstorm::Model::ExecutionCycle).to receive(:cpu_comparison_graph).and_return(chart_model)
        allow(Hailstorm::Model::ExecutionCycle).to receive(:memory_comparison_graph).and_return(chart_model)
        Hailstorm::Model::ExecutionCycle.create_report(project, cycle_ids, builder)
      end
    end

    context 'Execution cycles do not exist' do
      it 'should not build the report' do
        project = Hailstorm::Model::Project.new(project_code: 'execution_cycle_spec')
        builder = Hailstorm::Support::ReportBuilder.new
        expect(builder).to_not receive(:build)
        cycle_ids = [1, 3, 4]
        Hailstorm::Model::ExecutionCycle.create_report(project, cycle_ids, builder)
      end
    end
  end

  context '.execution_cycles_for_report' do
    context 'cycle_ids is nil or empty' do
      it 'should fetch all stopped execution cycles' do
        project = Hailstorm::Model::Project.new(project_code: 'execution_cycle_spec')
        expect(project).to respond_to(:execution_cycles)
        allow(project).to receive_message_chain(:execution_cycles, :where, :order, :all)
        expect(project.execution_cycles).to receive(:where).with(status: :stopped)
        Hailstorm::Model::ExecutionCycle.execution_cycles_for_report(project)
      end
    end
  end

  context '#formatted_started_at' do
    it 'should format as per ISO' do
      execution_cycle = Hailstorm::Model::ExecutionCycle.new(started_at: Time.new(2002, 9, 20, 1, 2, 3))
      expect(execution_cycle.formatted_started_at).to be == '2002-09-20 01:02'
    end
  end

  context '#formatted_stopped_at' do
    it 'should format as per ISO' do
      execution_cycle = Hailstorm::Model::ExecutionCycle.new(stopped_at: Time.new(2002, 9, 20, 1, 2, 3))
      expect(execution_cycle.formatted_stopped_at).to be == '2002-09-20 01:02'
    end
  end

  context 'with object graph' do
    before(:each) do
      project = Hailstorm::Model::Project.create!(project_code: 'execution_cycle_spec')
      @execution_cycle = Hailstorm::Model::ExecutionCycle.create!(project: project,
                                                                  status: :stopped,
                                                                  started_at: Time.now,
                                                                  stopped_at: Time.now + 15.minutes)
      @jmeter_plan_1 = Hailstorm::Model::JmeterPlan.create!(project: project,
                                                            test_plan_name: 'priming A',
                                                            content_hash: 'A',
                                                            properties: '{}',
                                                            latest_threads_count: 100)
      @jmeter_plan_1.update_column(:active, true)

      @jmeter_plan_2 = Hailstorm::Model::JmeterPlan.create!(project: project,
                                                            test_plan_name: 'priming B',
                                                            content_hash: 'B',
                                                            properties: '{}',
                                                            latest_threads_count: 100)
      @jmeter_plan_2.update_column(:active, true)

      @data_center = Hailstorm::Model::DataCenter.create!(project: project, machines: '["172.16.8.100"]',
                                                          ssh_identity: 'a')
      @data_center.update_column(:active, true)

      @zero_time = Time.new(2012, 2, 21, 10, 43, 23)

      Hailstorm::Model::ClientStat.create!(execution_cycle: @execution_cycle,
                                           jmeter_plan: @jmeter_plan_1,
                                           clusterable_id: @data_center.id,
                                           clusterable_type: @data_center.class,
                                           threads_count: 100,
                                           aggregate_ninety_percentile: 2000,
                                           aggregate_response_throughput: 50,
                                           last_sample_at: @zero_time - 15.minutes)

      Hailstorm::Model::ClientStat.create!(execution_cycle: @execution_cycle,
                                           jmeter_plan: @jmeter_plan_2,
                                           clusterable_id: @data_center.id,
                                           clusterable_type: @data_center.class,
                                           threads_count: 100,
                                           aggregate_ninety_percentile: 3000,
                                           aggregate_response_throughput: 100,
                                           last_sample_at: @zero_time - 10.minutes)
    end

    context '#avg_90_percentile' do
      it 'should average client_stats aggregate' do
        expect(@execution_cycle.avg_90_percentile).to be_within(1.0e-7).of(2500)
      end
    end

    context '#avg_tps' do
      it 'should average client_stats aggregate' do
        expect(@execution_cycle.avg_tps).to be_within(1.0e-7).of(75)
      end
    end

    context 'clusters' do
      it 'should return associated clusterables' do
        expect(@execution_cycle.clusters).to include(@data_center)
      end
    end

    context '#set_stopped_at' do
      it 'should set it at the last recorded client_stat' do
        @execution_cycle.set_stopped_at
        expect(@zero_time - @execution_cycle.stopped_at).to be == 10.minutes
      end
    end

    context '#jmeter_plans' do
      it 'should fetch associated jmeter_plans' do
        expect(@execution_cycle.jmeter_plans).to include(@jmeter_plan_1)
        expect(@execution_cycle.jmeter_plans).to include(@jmeter_plan_2)
      end
    end

    context 'status updates' do
      it 'should update to stopped' do
        @execution_cycle.stopped!
        expect(@execution_cycle.status).to be == :stopped
      end
      it 'should update to aborted' do
        @execution_cycle.aborted!
        expect(@execution_cycle.status).to be == :aborted
      end
      it 'should update to terminated' do
        @execution_cycle.terminated!
        expect(@execution_cycle.status).to be == :terminated
      end
      it 'should update to reported' do
        @execution_cycle.reported!
        expect(@execution_cycle.status).to be == :reported
      end
      it 'should update to excluded' do
        @execution_cycle.excluded!
        expect(@execution_cycle.status).to be == :excluded
      end
    end

    context '#export_results' do
      it 'should return path to exported files' do
        allow(FileUtils).to receive(:rm_rf)
        allow(FileUtils).to receive(:mkpath)
        allow_any_instance_of(Hailstorm::Model::ClientStat).to receive(:write_jtl) { |dir| "#{dir}/a.jtl" }
        paths = @execution_cycle.export_results(RSpec.configuration.build_path)
        expect(paths.size).to be == 2
      end
    end

    context '#import_results' do
      it 'should import JTL' do
        expect(@jmeter_plan_1).to respond_to(:num_threads)
        allow(@jmeter_plan_1).to receive(:num_threads).and_return(100)
        client_stat = Hailstorm::Model::ClientStat.new
        expect(client_stat).to respond_to(:first_sample_at, :last_sample_at)
        start_time = Time.new(2011, 6, 3, 15, 34, 12)
        end_time = Time.new(2011, 6, 3, 16, 28, 40)
        allow(client_stat).to receive(:first_sample_at).and_return(start_time)
        allow(client_stat).to receive(:last_sample_at).and_return(end_time)
        allow(Hailstorm::Model::ClientStat).to receive(:create_client_stat).and_return(client_stat)
        @execution_cycle.import_results(@jmeter_plan_1, @data_center, 'a.jtl')
        expect(@execution_cycle.started_at).to be == start_time
        expect(@execution_cycle.stopped_at).to be == end_time
      end
    end
  end

  context '#target_hosts' do
    it 'should fetch linked target_hosts' do
      project = Hailstorm::Model::Project.create!(project_code: 'execution_cycle_spec')
      execution_cycle = Hailstorm::Model::ExecutionCycle.create!(project: project,
                                                                 status: :stopped,
                                                                 started_at: Time.now,
                                                                 stopped_at: Time.now + 15.minutes)
      target_host = Hailstorm::Model::Nmon.create!(host_name: 'a', project: project, role_name: 'web')
      Hailstorm::Model::TargetStat.create!(execution_cycle: execution_cycle,
                                           target_host: target_host,
                                           average_cpu_usage: 25.34,
                                           average_memory_usage: 2345,
                                           average_swap_usage: 0)

      target_host.update_column(:active, true)

      expect(execution_cycle.target_hosts).to include(target_host)
    end
  end

  context '#execution_duration' do
    it 'should format as hours:minutes:seconds' do
      execution_cycle = Hailstorm::Model::ExecutionCycle.new
      execution_cycle.started_at = Time.new(2005, 12, 9, 11, 30, 15)
      execution_cycle.stopped_at = Time.new(2005, 12, 9, 13, 40, 20)
      expect(execution_cycle.execution_duration).to be == '02:10:05'
    end
  end

  context Hailstorm::Model::ExecutionCycle::GraphBuilderFactory do
    it 'should create cpu target_comparison_graph builder' do
      expect(Hailstorm::Model::ExecutionCycle::GraphBuilderFactory
               .target_comparison_graph('foo', metric: :cpu)).to_not be_nil
    end

    it 'should create memory target_comparison_graph builder' do
      expect(Hailstorm::Model::ExecutionCycle::GraphBuilderFactory
                 .target_comparison_graph('foo', metric: :memory)).to_not be_nil
    end

    it 'should raise error if unknown metric is applied' do
      klass = Hailstorm::Model::ExecutionCycle::GraphBuilderFactory
      expect { klass.target_comparison_graph('foo', metric: :other) }.to raise_error(ArgumentError)
    end

    it 'should create client_comparison_graph builder' do
      expect(Hailstorm::Model::ExecutionCycle::GraphBuilderFactory
              .client_comparison_graph('foo')).to_not be_nil
    end

    it 'should create time_series_graph builder' do
      expect(Hailstorm::Model::ExecutionCycle::GraphBuilderFactory
                 .time_series_graph(series_name: 'Requests/second',
                                    range_name: 'Requests',
                                    start_time: Time.now.to_i)).to_not be_nil
    end

  end

  context 'execution_cycles comparison graph' do
    it 'should build the graph' do
      project = Hailstorm::Model::Project.create!(project_code: 'target_stat_spec')
      allow_any_instance_of(Hailstorm::Model::Nmon).to receive(:transfer_identity_file)
      target_host = Hailstorm::Model::Nmon.create!(host_name: 'a',
                                                   project: project,
                                                   role_name: 'server',
                                                   ssh_identity: 'a',
                                                   user_name: 'ubuntu')
      target_host.update_column(:active, true)
      execution_cycles = [30, 30, 50, 100].map.with_index do |threads_count, index|
        t = Time.new(2010, 10, 8, 10, 0, 0)
        execution_cycle = Hailstorm::Model::ExecutionCycle.create!(project: project,
                                                                   status: :stopped,
                                                                   started_at: t,
                                                                   stopped_at: t + index.hours,
                                                                   threads_count: threads_count)

        allow_any_instance_of(Hailstorm::Model::TargetStat).to receive(:write_blobs)
        2.times do
          Hailstorm::Model::TargetStat.create!(execution_cycle: execution_cycle,
                                               target_host: target_host,
                                               average_cpu_usage: 25.0,
                                               average_memory_usage: 2345.5)
        end
        execution_cycle
      end

      grapher = spy('TargetComparisonGraph')
      expect(grapher).to receive(:build).exactly(2).times

      Hailstorm::Model::ExecutionCycle.cpu_comparison_graph(execution_cycles,
                                                            builder: grapher,
                                                            working_path: RSpec.configuration.build_path)
      Hailstorm::Model::ExecutionCycle.memory_comparison_graph(execution_cycles,
                                                               builder: grapher,
                                                               working_path: RSpec.configuration.build_path)
    end
  end

  context '#client_comparison_graph' do
    it 'should compare response time and throughput across executions' do
      project = Hailstorm::Model::Project.create!(project_code: 'execution_cycle_spec')
      refs_ary = 2.times.map { create_client_stat_refs(project)  }
      execution_cycles = refs_ary.map do |clusterable, execution_cycle, jmeter_plan|
        t = Time.new(2010, 10, 7, 14, 23, 45)
        Hailstorm::Model::ClientStat.create!(execution_cycle: execution_cycle,
                                             jmeter_plan: jmeter_plan,
                                             clusterable: clusterable,
                                             threads_count: 30,
                                             aggregate_ninety_percentile: 1500,
                                             aggregate_response_throughput: 3000,
                                             last_sample_at: t)
        3.times do |index|
          Hailstorm::Model::ClientStat.create!(execution_cycle: execution_cycle,
                                               jmeter_plan: jmeter_plan,
                                               clusterable: clusterable,
                                               threads_count: 30 * (index + 1),
                                               aggregate_ninety_percentile: 1500,
                                               aggregate_response_throughput: 3000,
                                               last_sample_at: t + (index + 1).hours)
        end
        execution_cycle
      end

      grapher = double('ExecutionComparisonGraph',
                       addResponseTimeDataItem: nil,
                       addThroughputDataItem: nil,
                       'output_path=': nil)
      expect(grapher).to receive(:build)
      Hailstorm::Model::ExecutionCycle.client_comparison_graph(execution_cycles,
                                                               builder: grapher,
                                                               working_path: RSpec.configuration.build_path)
    end
  end

  context 'time series graphs' do
    it 'should build the graphs' do
      clusterable, execution_cycle, jmeter_plan = create_client_stat_refs
      2.times.map do |index|
        Hailstorm::Model::ClientStat.create!(execution_cycle: execution_cycle,
                                             jmeter_plan: jmeter_plan,
                                             clusterable: clusterable,
                                             threads_count: 30 * (index + 1),
                                             aggregate_ninety_percentile: 1500,
                                             aggregate_response_throughput: 3000,
                                             last_sample_at: Time.new(2010, 10, 7, 14 + index, 23, 45))
      end

      allow_any_instance_of(Hailstorm::Model::ClientStat).to receive(:write_jtl) do
        file_path = Tempfile.new
        File.write(file_path, JTL_LOG_DATA)
        file_path
      end

      grapher = double('TimeSeriesGraph', addDataPoint: nil, 'series_name=': nil, 'range_name=': nil,
                       'start_time=': nil)

      expect(grapher).to receive(:build).exactly(3).times
      execution_cycle.hits_per_second_graph(builder: grapher, working_path: RSpec.configuration.build_path)
      execution_cycle.active_threads_over_time_graph(builder: grapher, working_path: RSpec.configuration.build_path)
      execution_cycle.throughput_over_time_graph(builder: grapher, working_path: RSpec.configuration.build_path)
    end
  end
end
