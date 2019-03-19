require 'spec_helper'
require 'tempfile'
require 'jtl_log_data'
require 'hailstorm/model/client_stat'
require 'hailstorm/model/amazon_cloud'
require 'hailstorm/model/master_agent'
require 'hailstorm/model/page_stat'

describe Hailstorm::Model::ClientStat do

  def create_client_stat_refs(project = nil)
    project ||= Hailstorm::Model::Project.create!(project_code: 'execution_cycle_spec')
    execution_cycle = Hailstorm::Model::ExecutionCycle.create!(project: project,
                                                               status: :stopped,
                                                               started_at: Time.now,
                                                               stopped_at: Time.now + 15.minutes)
    jmeter_plan = Hailstorm::Model::JmeterPlan.create!(project: project,
                                                       test_plan_name: 'priming',
                                                       content_hash: 'A',
                                                       latest_threads_count: 100)
    jmeter_plan.update_column(:active, true)
    clusterable = Hailstorm::Model::AmazonCloud.create!(project: project,
                                                        access_key: 'A',
                                                        secret_key: 'A',
                                                        region: 'us-east-1')
    clusterable.update_column(:active, true)
    [clusterable, execution_cycle, jmeter_plan]
  end

  context '.collect_client_stats' do
    it 'should collect create_client_stats' do
      cluster_instance = Hailstorm::Model::AmazonCloud.new
      expect(cluster_instance).to respond_to(:master_agents)
      agent_generator = Proc.new do |jmeter_plan_id, result_file|
        agent = Hailstorm::Model::MasterAgent.new
        agent.jmeter_plan_id = jmeter_plan_id
        expect(agent).to respond_to(:result_for)
        agent.stub!(:result_for).and_return(result_file)
        agent
      end
      uniq_ids = []
      agents = [[1, 'a.jtl'], [1, 'b.jtl'], [2, 'c.jtl']].map do |id, file|
        uniq_ids.push(id) unless uniq_ids.include?(id)
        agent_generator.call(id, file)
      end
      cluster_instance.stub_chain(:master_agents, :where).and_return(agents)
      Hailstorm::Model::ClientStat.should_receive(:create_client_stat).exactly(uniq_ids.size).times
      Hailstorm::Model::ClientStat.collect_client_stats(mock(Hailstorm::Model::ExecutionCycle), cluster_instance)
    end
  end

  context '.create_client_stat' do
    it 'should invoke ClientStatTemplate' do
      Hailstorm::Model::ClientStat::ClientStatTemplate
        .any_instance
        .stub(:create)
        .and_return(Hailstorm::Model::ClientStat.new)
      Hailstorm::Model::JmeterPlan.stub!(:find).and_return(mock(Hailstorm::Model::JmeterPlan))
      expect(Hailstorm::Model::ClientStat
               .create_client_stat(mock(Hailstorm::Model::ExecutionCycle),
                                   1,
                                   mock(Hailstorm::Model::AmazonCloud),
                                   [])).to be_a(Hailstorm::Model::ClientStat)
    end
  end

  context Hailstorm::Model::ClientStat::ClientStatTemplate do
    it 'should not combine_stats for single file' do
      stat_file_paths = [ Tempfile.new ]
      template = Hailstorm::Model::ClientStat::ClientStatTemplate.new(nil, nil, nil, stat_file_paths, false)
      template.should_not_receive(:combine_stats)
      template.stub!(:do_create_client_stat)
      template.stub!(:persist_jtl)
      template.create
      stat_file_paths.each { |sfp| sfp.unlink }
    end
    it 'should combine_stats for multiple files' do
      stat_file_paths = [ Tempfile.new, Tempfile.new ]
      template = Hailstorm::Model::ClientStat::ClientStatTemplate.new(nil, nil, nil, stat_file_paths, false)
      template.should_receive(:combine_stats).and_return(stat_file_paths.first)
      template.stub!(:do_create_client_stat)
      template.stub!(:persist_jtl)
      template.create
      stat_file_paths.each { |sfp| sfp.unlink }
    end
    it 'should delete stat_file_paths' do
      stat_file_paths = [ Tempfile.new, Tempfile.new ]
      combined_path = Tempfile.new
      template = Hailstorm::Model::ClientStat::ClientStatTemplate.new(nil, nil, nil, stat_file_paths, true)
      template.should_receive(:combine_stats).and_return(combined_path)
      template.stub!(:do_create_client_stat)
      template.stub!(:persist_jtl)
      template.create
      expect(File.exist?(combined_path)).to be_false
      stat_file_paths.each { |sfp| sfp.unlink }
    end
    it 'should create a client_stat' do
      clusterable, execution_cycle, jmeter_plan = create_client_stat_refs
      Hailstorm::Model::JtlFile.stub!(:persist_file)
      File.stub!(:open).and_yield(JTL_LOG_DATA.strip_heredoc)

      template = Hailstorm::Model::ClientStat::ClientStatTemplate.new(jmeter_plan, execution_cycle, clusterable, [], false)
      template.stub!(:collate_stats)
      client_stat = template.create
      expect(client_stat).to_not be_nil
      expect(client_stat.first_sample_at).to_not be_nil
    end

    it 'should combine samples from multiple files' do
      log_data =<<-JTL
      <?xml version="1.0" encoding="UTF-8"?>
      <testResults version="1.2">
        <sample t="14256" lt="0" ts="1354685431293" s="true" lb="Home Page" rc="200" rm="Number of samples in transaction : 3, number of failing samples : 0" tn=" Static Pages 1-1" dt="" by="33154">
          <httpSample t="13252" lt="13191" ts="1354685436312" s="true" lb="/Home.aspx" rc="200" rm="OK" tn=" Static Pages 1-1" dt="text" by="21967"/>
        </sample>
      </testResults>
      JTL
      FILES_COUNT = 3
      stat_file_paths = FILES_COUNT.times.map do
        Tempfile.new.tap do |file|
          File.open(file, 'w') do |fio|
            fio.write(log_data.strip_heredoc)
          end
        end
      end

      template = Hailstorm::Model::ClientStat::ClientStatTemplate
                   .new(mock(Hailstorm::Model::JmeterPlan, id: 1),
                        mock(Hailstorm::Model::ExecutionCycle, id: 1),
                        mock(Hailstorm::Model::AmazonCloud, id: 1),
                        stat_file_paths,
                        true)

      template.stub!(:do_create_client_stat)
      template.should_receive(:persist_jtl) do |_client_stat, combined_path|
        doc = Nokogiri::XML.parse(File.read(combined_path))
        expect(doc.xpath('/testResults').length).to be == 1
        expect(doc.xpath('/testResults/sample').length).to be == FILES_COUNT
      end

      template.create
    end
  end

  context '#aggregate_graph' do
    it 'should build the graph' do
      clusterable, execution_cycle, jmeter_plan = create_client_stat_refs
      client_stat = Hailstorm::Model::ClientStat.create!(execution_cycle: execution_cycle,
                                                         jmeter_plan: jmeter_plan,
                                                         clusterable: clusterable,
                                                         threads_count: 30,
                                                         aggregate_ninety_percentile: 1500,
                                                         aggregate_response_throughput: 3000,
                                                         last_sample_at: Time.new(2010, 10, 7, 14, 23, 45))

      Hailstorm::Model::PageStat.any_instance.stub(:calculate_aggregates)
      3.times do |index|
        Hailstorm::Model::PageStat.create!(client_stat: client_stat,
                                           page_label: "label-#{index}",
                                           average_response_time: 500,
                                           median_response_time: 450,
                                           ninety_percentile_response_time: 470,
                                           minimum_response_time: 400,
                                           maximum_response_time: 650,
                                           percentage_errors: 2.34,
                                           response_throughput: 1000,
                                           size_throughput: 123,
                                           standard_deviation: 1.5,
                                           samples_breakup_json: '[{"r": 1}, {"r": [1, 3]}, {"r": [3, 5]}, {"r": 5}]')
      end

      client_stat.should_receive(:build_aggregate_graph)
      client_stat.aggregate_graph
    end
  end

  context '#execution_comparison_graph' do
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
      grapher.should_receive(:build)
      Hailstorm::Model::ClientStat.execution_comparison_graph(execution_cycles, grapher: grapher)
    end
  end

  context '#write_jtl' do
    it 'should export JTL' do
      clusterable, execution_cycle, jmeter_plan = create_client_stat_refs
      client_stat = Hailstorm::Model::ClientStat.create!(execution_cycle: execution_cycle,
                                                         jmeter_plan: jmeter_plan,
                                                         clusterable: clusterable,
                                                         threads_count: 30,
                                                         aggregate_ninety_percentile: 1500,
                                                         aggregate_response_throughput: 3000,
                                                         last_sample_at: Time.new(2010, 10, 7, 14, 23, 45))
      Hailstorm::Model::JtlFile.stub!(:export_file)
      expect(client_stat.write_jtl('foo', true)).to match(/^foo.+\.jtl$/)
    end
  end

  context 'TimeSeriesGraph' do
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

      Hailstorm::Model::ClientStat.any_instance.stub(:write_jtl) do
        file_path = Tempfile.new
        File.write(file_path, JTL_LOG_DATA)
        file_path
      end

      grapher = double('TimeSeriesGraph', addDataPoint: nil)
      grapher.should_receive(:build).exactly(3).times
      Hailstorm::Model::ClientStat.hits_per_second_graph(execution_cycle, grapher: grapher)
      Hailstorm::Model::ClientStat.active_threads_over_time_graph(execution_cycle, grapher: grapher)
      Hailstorm::Model::ClientStat.throughput_over_time_graph(execution_cycle, grapher: grapher)
    end
  end
end
