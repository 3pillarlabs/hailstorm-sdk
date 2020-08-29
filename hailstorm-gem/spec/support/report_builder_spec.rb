require 'spec_helper'
require 'ostruct'
require 'hailstorm/support/report_builder'
require 'hailstorm/model/jmeter_plan'
require 'hailstorm/model/target_host'

describe Hailstorm::Support::ReportBuilder do

  context '#test_summary_rows' do
    it 'should return host names' do
      report_builder = Hailstorm::Support::ReportBuilder.new
      report_builder.test_summary_rows do |row|
        row.jmeter_plans = [ Hailstorm::Model::JmeterPlan.new ]
        row.test_duration = 1000
        row.total_threads_count = 15
        row.target_hosts = [ Hailstorm::Model::TargetHost.new(host_name: 'a'),
                             Hailstorm::Model::TargetHost.new(host_name: 'b'),
                             'c']

      end
      expect(report_builder.test_summary_rows[0].target_hosts).to be == 'a, b, c'
    end
  end

  context '#targets_by_role' do
    it 'should group target hosts across execution cycles by role' do
      report_builder = Hailstorm::Support::ReportBuilder.new
      host_names_ite = %w[web01 db01 web02 db01].each
      2.times do
        report_builder.execution_detail_items do |item|
          item.target_stats do |target_stat_item|
            target_stat_item.role_name = 'Web Server'
            target_stat_item.host_name = host_names_ite.next
          end
          item.target_stats do |target_stat_item|
            target_stat_item.role_name = 'Database'
            target_stat_item.host_name = host_names_ite.next
          end
        end
      end

      group = report_builder.targets_by_role
      expect(group).to have_key('Web Server')
      expect(group['Web Server']).to be == %w[web01 web02]
      expect(group).to have_key('Database')
      expect(group['Database']).to be == %w[db01]
    end
  end

  context '#all_clusters' do
    it 'should return all unique names' do
      report_builder = Hailstorm::Support::ReportBuilder.new
      %w[a b b c].each do |name|
        report_builder.execution_detail_items do |item|
          item.clusters do |cluster_item|
            cluster_item.name = name
          end
          expect(item).to_not be_multiple_cluster
        end
      end

      expect(report_builder.all_clusters.collect(&:name)).to be == %w[a b c]
    end
  end

  context '#build' do
    it 'should build the report' do
      report_builder = Hailstorm::Support::ReportBuilder.new
      report_builder.jmeter_plans = %w[a b c].map do |name|
        jmeter_plan = Hailstorm::Model::JmeterPlan.new(test_plan_name: name)
        allow(jmeter_plan).to receive(:plan_name).and_return(name)
        allow(jmeter_plan).to receive(:plan_description).and_return(nil)
        main_samplers = OpenStruct.new(thread_group: 'main', samplers: %w[a, b])
        allow(jmeter_plan).to receive(:scenario_definitions).and_return([main_samplers])
        jmeter_plan
      end
      2.times do |index|
        report_builder.test_summary_rows do |row|
          row.jmeter_plans = 'a, b, c'
          row.target_hosts = ['x']
          row.total_threads_count = 100 * (index + 1)
          row.test_duration = 100
        end
        report_builder.execution_detail_items do |execution|
          execution.total_threads_count = 100 * (index + 1)

          execution.clusters do |cluster|
            cluster.name = 'a'
            cluster.client_stats do |client_stat|
              client_stat.name = 'a'
              client_stat.threads_count = 100
              client_stat.aggregate_stats = [ spy('aggregate_stats') ]
              client_stat.aggregate_graph do |graph|
                graph.chart_model = double('chart model', getFilePath: 'a', getWidth: 600, getHeight: 400)
              end
            end
          end

          execution.target_stats do |target_stat|
            target_stat.role_name = 'Web Server'
            target_stat.host_name = 'web01'
            target_stat.utilization_graph do |graph|
              graph.chart_model = double('chart model', getFilePath: 'b', getWidth: 600, getHeight: 400)
            end
          end

          execution.hits_per_second_graph do |graph|
            graph.chart_model = double('chart model', getFilePath: 'c', getWidth: 600, getHeight: 400)
          end

          execution.active_threads_over_time_graph do |graph|
            graph.chart_model = double('chart model', getFilePath: 'c', getWidth: 600, getHeight: 400)
          end

          execution.throughput_over_time_graph do |graph|
            graph.chart_model = double('chart model', getFilePath: 'c', getWidth: 600, getHeight: 400)
          end
        end
      end

      report_builder.client_comparison_graph do |graph|
        graph.chart_model = double('chart model', getFilePath: 'c', getWidth: 600, getHeight: 400)
      end

      report_builder.target_cpu_comparison_graph do |graph|
        graph.chart_model = double('chart model', getFilePath: 'c', getWidth: 600, getHeight: 400)
      end

      report_builder.target_memory_comparison_graph do |graph|
        graph.chart_model = double('chart model', getFilePath: 'c', getWidth: 600, getHeight: 400)
      end

      allow(FileUtils).to receive(:move)
      report_builder.build(RSpec.configuration.build_path, 'a.docx')
    end
  end
end
