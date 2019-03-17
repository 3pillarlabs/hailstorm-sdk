require 'spec_helper'
require 'hailstorm/model/execution_cycle'
require 'hailstorm/model/amazon_cloud'
require 'hailstorm/model/data_center'
require 'hailstorm/model/nmon'

describe Hailstorm::Model::ExecutionCycle do

  def generate_execution_cycles(cycle_ids = [])
    cycle_ids.map do |cycle_id|
      execution_cycle = Hailstorm::Model::ExecutionCycle.new
      execution_cycle.started!
      execution_cycle.id = cycle_id

      chart_model = mock('ChartModel', getFilePath: '', getWidth: 800, getHeight: 600)

      expect(execution_cycle).to respond_to(:clusters)
      cluster = Hailstorm::Model::AmazonCloud.new
      client_stat = Hailstorm::Model::ClientStat.new
      expect(client_stat).to respond_to(:jmeter_plan)
      jmeter_plan = Hailstorm::Model::JmeterPlan.new
      expect(jmeter_plan).to respond_to(:plan_name)
      jmeter_plan.stub!(:plan_name).and_return('Priming test')
      client_stat.stub!(:jmeter_plan).and_return(jmeter_plan)
      client_stat.stub!(:aggregate_graph).and_return(chart_model)
      expect(cluster).to respond_to(:client_stats)
      cluster.stub_chain(:client_stats, :where).and_return([ client_stat ])
      execution_cycle.stub!(:clusters).and_return([cluster])

      expect(execution_cycle).to respond_to(:target_stats)
      target_stat = Hailstorm::Model::TargetStat.new
      expect(target_stat).to respond_to(:target_host)
      target_stat.stub!(:target_host).and_return(Hailstorm::Model::TargetHost.new)
      target_stat.stub!(:utilization_graph).and_return(chart_model)
      execution_cycle.stub!(:target_stats).and_return([target_stat])
      execution_cycle.stub!(:target_hosts).and_return([target_stat.target_host])
      execution_cycle
    end
  end

  context '.create_report' do
    context 'Execution cycles exist' do
      it 'should build the report' do
        project = Hailstorm::Model::Project.new(project_code: 'execution_cycle_spec')
        builder = Hailstorm::Support::ReportBuilder.new
        builder.should_receive(:build)
        cycle_ids = [1, 3, 4]
        Hailstorm::Model::ExecutionCycle
            .stub!(:execution_cycles_for_report)
            .and_return(generate_execution_cycles(cycle_ids))
        chart_model = mock('ChartModel', getFilePath: '', getWidth: 800, getHeight: 600)
        Hailstorm::Model::ClientStat.stub!(:hits_per_second_graph).and_return(chart_model)
        Hailstorm::Model::ClientStat.stub!(:active_threads_over_time_graph).and_return(chart_model)
        Hailstorm::Model::ClientStat.stub!(:throughput_over_time_graph).and_return(chart_model)
        Hailstorm::Model::ClientStat.stub!(:execution_comparison_graph).and_return(chart_model)
        Hailstorm::Model::TargetStat.stub!(:cpu_comparison_graph).and_return(chart_model)
        Hailstorm::Model::TargetStat.stub!(:memory_comparison_graph).and_return(chart_model)
        Hailstorm::Model::ExecutionCycle.create_report(project, cycle_ids, builder)
      end
    end

    context 'Execution cycles do not exist' do
      it 'should not build the report' do
        project = Hailstorm::Model::Project.new(project_code: 'execution_cycle_spec')
        builder = Hailstorm::Support::ReportBuilder.new
        builder.should_not_receive(:build)
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
        project.stub_chain(:execution_cycles, :where, :order, :all)
        project.execution_cycles.should_receive(:where).with(status: :stopped)
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

      @data_center = Hailstorm::Model::DataCenter.create!(project: project, machines: '["172.16.8.100"]')
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
        FileUtils.stub!(:rm_rf)
        FileUtils.stub!(:mkpath)
        Hailstorm::Model::ClientStat.any_instance.stub(:write_jtl) { |dir| "#{dir}/a.jtl" }
        paths = @execution_cycle.export_results
        expect(paths.size).to be == 2
      end
    end

    context '#import_results' do
      it 'should import JTL' do
        expect(@jmeter_plan_1).to respond_to(:num_threads)
        @jmeter_plan_1.stub!(:num_threads).and_return(100)
        client_stat = Hailstorm::Model::ClientStat.new
        expect(client_stat).to respond_to(:first_sample_at, :last_sample_at)
        start_time = Time.new(2011, 6, 3, 15, 34, 12)
        end_time = Time.new(2011, 6, 3, 16, 28, 40)
        client_stat.stub!(:first_sample_at).and_return(start_time)
        client_stat.stub!(:last_sample_at).and_return(end_time)
        Hailstorm::Model::ClientStat.stub!(:create_client_stat).and_return(client_stat)
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
end
