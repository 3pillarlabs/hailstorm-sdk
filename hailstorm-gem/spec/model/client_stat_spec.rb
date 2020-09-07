# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'
require 'jtl_log_data'
require 'hailstorm/model/client_stat'
require 'hailstorm/model/amazon_cloud'
require 'hailstorm/model/master_agent'
require 'hailstorm/model/page_stat'
require 'hailstorm/model/project'
require 'client_stats_helper'

describe Hailstorm::Model::ClientStat do
  include ClientStatsHelper

  context '.collect_client_stats' do
    it 'should collect create_client_stats' do
      cluster_instance = Hailstorm::Model::AmazonCloud.new
      cluster_instance.project = Hailstorm::Model::Project.create!(project_code: 'client_stat_spec')
      expect(cluster_instance).to respond_to(:master_agents)
      agent_generator = proc do |jmeter_plan_id, result_file|
        agent = Hailstorm::Model::MasterAgent.new
        agent.jmeter_plan_id = jmeter_plan_id
        expect(agent).to respond_to(:result_for)
        allow(agent).to receive(:result_for).and_return(result_file)
        agent
      end
      uniq_ids = []
      agents = [[1, 'a.jtl'], [1, 'b.jtl'], [2, 'c.jtl']].map do |id, file|
        uniq_ids.push(id) unless uniq_ids.include?(id)
        agent_generator.call(id, file)
      end
      allow(cluster_instance).to receive_message_chain(:master_agents, :where, :all).and_return(agents)
      expect(Hailstorm::Model::ClientStat).to receive(:create_client_stat).exactly(uniq_ids.size).times
      allow(File).to receive(:unlink)
      mock_execution_cycle = instance_double(Hailstorm::Model::ExecutionCycle)
      Hailstorm::Model::ClientStat.collect_client_stats(mock_execution_cycle, cluster_instance)
    end
  end

  context '.create_client_stat' do
    it 'should invoke ClientStatTemplate' do
      results = [Hailstorm::Model::ClientStat.new, nil]
      allow_any_instance_of(Hailstorm::Model::ClientStat::ClientStatTemplate).to receive(:create).and_return(results)
      allow(Hailstorm::Model::JmeterPlan).to receive(:find).and_return(instance_double(Hailstorm::Model::JmeterPlan))
      expect(Hailstorm::Model::ClientStat
               .create_client_stat(instance_double(Hailstorm::Model::ExecutionCycle),
                                   1,
                                   instance_double(Hailstorm::Model::AmazonCloud),
                                   []).first).to be_a(Hailstorm::Model::ClientStat)
    end
  end

  context Hailstorm::Model::ClientStat::ClientStatTemplate do
    it 'should not combine_stats for single file' do
      stat_file_paths = [Tempfile.new]
      template = Hailstorm::Model::ClientStat::ClientStatTemplate.new(nil, nil, nil, stat_file_paths)
      expect(template).to_not receive(:combine_stats)
      allow(template).to receive(:do_create_client_stat)
      allow(template).to receive(:persist_jtl)
      template.create
      stat_file_paths.each(&:unlink)
    end

    it 'should combine_stats for multiple files' do
      stat_file_paths = [Tempfile.new, Tempfile.new]
      template = Hailstorm::Model::ClientStat::ClientStatTemplate.new(nil, nil, nil, stat_file_paths)
      expect(template).to receive(:combine_stats).and_return(stat_file_paths.first)
      allow(template).to receive(:do_create_client_stat)
      allow(template).to receive(:persist_jtl)
      template.create
      stat_file_paths.each(&:unlink)
    end

    it 'should delete stat_file_paths' do
      stat_file_paths = [Tempfile.new, Tempfile.new]
      combined_path = Tempfile.new
      template = Hailstorm::Model::ClientStat::ClientStatTemplate.new(nil, nil, nil, stat_file_paths)
      expect(template).to receive(:combine_stats).and_return(combined_path)
      allow(template).to receive(:do_create_client_stat)
      allow(template).to receive(:persist_jtl)
      template.create
      stat_file_paths.each(&:unlink)
    end

    it 'should create a client_stat' do
      clusterable, execution_cycle, jmeter_plan = create_client_stat_refs
      allow(Hailstorm::Model::JtlFile).to receive(:persist_file)
      allow(File).to receive(:open).and_yield(JTL_LOG_DATA.strip_heredoc)

      template = Hailstorm::Model::ClientStat::ClientStatTemplate.new(jmeter_plan, execution_cycle, clusterable, [])
      allow(template).to receive(:collate_stats)
      client_stat, = template.create
      expect(client_stat).to_not be_nil
      expect(client_stat.first_sample_at).to_not be_nil
    end

    it 'should combine samples from multiple files' do
      log_data = <<-JTL
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

      project = Hailstorm::Model::Project.create!(project_code: 'client_stat_spec')
      template = Hailstorm::Model::ClientStat::ClientStatTemplate
                 .new(instance_double(Hailstorm::Model::JmeterPlan, id: 1),
                      instance_double(Hailstorm::Model::ExecutionCycle, id: 1, project: project),
                      instance_double(Hailstorm::Model::AmazonCloud, id: 1),
                      stat_file_paths)

      allow(template).to receive(:do_create_client_stat)
      expect(template).to receive(:persist_jtl) do |_client_stat, combined_path|
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

      allow_any_instance_of(Hailstorm::Model::PageStat).to receive(:calculate_aggregates)
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

      builder = double('GraphBuilder', create: 'foo.png', 'output_path=': nil)
      class << builder
        # :nocov:
        def method_missing(name, *args, &block)
          if name.to_s =~ /^set/
            self
          else
            super
          end
        end

        def respond_to_missing?(name, _include_all)
          name.to_s =~ /^set/ ? true : super
        end
        # :nocov:
      end
      client_stat.aggregate_graph(builder: builder, working_path: RSpec.configuration.build_path)
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
      allow(Hailstorm::Model::JtlFile).to receive(:export_file)
      expect(client_stat.write_jtl('foo', append_id: true)).to match(/^foo.+\.jtl$/)
    end
  end

  context Hailstorm::Model::ClientStat::GraphBuilderFactory do
    it 'should create aggregate_graph builder' do
      expect(Hailstorm::Model::ClientStat::GraphBuilderFactory
               .aggregate_graph(identifier: 1, working_path: RSpec.configuration.build_path)).to_not be_nil
    end
  end
end
