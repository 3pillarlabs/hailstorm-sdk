# frozen_string_literal: true

require 'nokogiri'

require 'hailstorm/model'
require 'hailstorm/model/execution_cycle'
require 'hailstorm/model/jmeter_plan'
require 'hailstorm/model/page_stat'
require 'hailstorm/model/jtl_file'
require 'hailstorm/support/quantile'
require 'hailstorm/support/collection_helper'

# Statistics collected on the 'client' side.
# @author Sayantam Dey
class Hailstorm::Model::ClientStat < ActiveRecord::Base
  include Hailstorm::Support::CollectionHelper

  belongs_to :execution_cycle

  belongs_to :jmeter_plan

  belongs_to :clusterable, polymorphic: true

  has_many :page_stats, dependent: :destroy

  has_many :jtl_files, dependent: :delete_all

  # starting (minimum) timestamp of collected samples
  attr_accessor :start_timestamp

  # last sample collected
  attr_accessor :end_sample

  # Array to store 90% response time of all samples
  attr_accessor :sample_response_times

  after_initialize :set_defaults

  # Collects the statistics generated by the load generating cluster
  # @param [Hailstorm::Model::ExecutionCycle] execution_cycle
  # @param [Hailstorm::Behavior::Clusterable] cluster_instance
  def self.collect_client_stats(execution_cycle, cluster_instance)
    logger.debug { "#{self.class}.#{__method__}" }
    jmeter_plan_results_map = fetch_results(execution_cycle, cluster_instance)
    jmeter_plan_results_map.keys.sort.each do |jmeter_plan_id|
      stat_file_paths = jmeter_plan_results_map[jmeter_plan_id]
      self.create_client_stat(execution_cycle, jmeter_plan_id, cluster_instance, stat_file_paths)
      stat_file_paths.each { |file_path| File.unlink(file_path) }
    end
  end

  # @param [Hailstorm::Model::ExecutionCycle] execution_cycle
  # @param [Hailstorm::Behavior::Clusterable] cluster_instance
  def self.fetch_results(execution_cycle, cluster_instance)
    jmeter_plan_results_map = Hash.new { |h, k| h[k] = [] }
    result_mutex = Mutex.new
    local_log_path = Hailstorm.workspace(cluster_instance.project.project_code).tmp_path

    self.visit_collection(cluster_instance.master_agents.where(active: true).all) do |master|
      result_file_name = master.result_for(execution_cycle, local_log_path)
      result_file_path = File.join(local_log_path, result_file_name)
      result_mutex.synchronize do
        jmeter_plan_results_map[master.jmeter_plan_id].push(result_file_path)
      end
    end

    jmeter_plan_results_map
  end

  # create 1 record for client_stats if it does not exist yet
  # @param [Hailstorm::Model::ExecutionCycle] execution_cycle
  # @param [Integer] jmeter_plan_id
  # @param [Hailstorm::Behavior::Clusterable] clusterable
  # @param [Array<String>] stat_file_paths
  # @param [Boolean] rm_stat_file
  # @return [[Hailstorm::Model::ClientStat, String]] [client_stat, combined_file_path: nil]
  def self.create_client_stat(execution_cycle, jmeter_plan_id, clusterable, stat_file_paths)
    jmeter_plan = Hailstorm::Model::JmeterPlan.find(jmeter_plan_id)
    template = ClientStatTemplate.new(jmeter_plan, execution_cycle, clusterable, stat_file_paths)
    template.logger = logger
    template.create
  end

  # @return [String] path to generated image
  def aggregate_graph(working_path:, builder: nil)
    page_labels = self.page_stats.collect(&:page_label)
    threshold_data, threshold_titles = build_threshold_matrix
    error_percentages = self.page_stats.collect(&:percentage_errors)
    grapher = GraphBuilderFactory.aggregate_graph(identifier: self.id,
                                                  other_builder: builder,
                                                  working_path: working_path)
    grapher.setPages(page_labels)
           .setNinetyCentileResponseTimes(response_time_matrix[3])
           .setThresholdTitles(threshold_titles)
           .setThresholdData(threshold_data)
           .setErrorPercentages(error_percentages)
           .create
  end

  def aggregate_stats
    self.page_stats.collect(&:stat_item)
  end

  def collect_sample(sample)
    sample_timestamp = sample['ts'].to_f

    # start_timestamp
    self.start_timestamp = sample_timestamp if self.start_timestamp.nil? || (sample_timestamp < self.start_timestamp)

    # end_sample
    self.end_sample = sample if self.end_sample.nil? || (sample_timestamp > self.end_sample['ts'].to_f)

    self.sample_response_times.push(sample['t'])
  end

  # @param [String] export_dir_path Path to local directory for exported files
  # @return [String] path to exported file
  def write_jtl(export_dir_path, append_id: false)
    require(self.clusterable_type.underscore)
    file_name = [self.clusterable.slug.gsub(/[\W\s]+/, '_'),
                 self.jmeter_plan.test_plan_name.gsub(/[\W\s]+/, '_')].join('-')
    file_name.concat("-#{self.id}") if append_id
    file_name.concat('.jtl')

    export_file = File.join(export_dir_path, file_name)
    Hailstorm::Model::JtlFile.export_file(self, export_file) unless File.exist?(export_file)
    export_file
  end

  def first_sample_at
    Time.at((self.start_timestamp / 1000).to_i) if self.start_timestamp
  end

  def test_duration
    (self.end_sample['ts'].to_f + self.end_sample['t'].to_f - self.start_timestamp) / 1000.to_f
  end

  # this is the duration of the last sample sent, it is in milliseconds, so
  # we divide it by 1000
  def sample_duration
    (self.end_sample['ts'].to_i + self.end_sample['t'].to_i)
  end

  # Receives event callbacks as XML is parsed
  class JtlDocument < Nokogiri::XML::SAX::Document
    attr_reader :page_stats_map

    def initialize(stat_klass, client_stat)
      super()

      @stat_klass = stat_klass
      @client_stat = client_stat
      @page_stats_map = {}
      @level = 0
    end

    # @overrides Nokogiri::XML::SAX::Document#start_element()
    # @param [String] name
    # @param [Array] attrs
    def start_element(name, attrs = [])
      # check for level 1 because we don't collect sub-samples
      if (@level == 1) && %w[httpSample sample].include?(name)
        attrs_map = Hash[attrs] # convert array of 2 element arrays to Hash
        label = attrs_map['lb'].strip
        unless @page_stats_map.key?(label)
          @page_stats_map[label] = @stat_klass.new(page_label: label, client_stat_id: @client_stat.id)
        end
        @client_stat.collect_sample(attrs_map)
        @page_stats_map[label].collect_sample(attrs_map)
      end
      @level += 1
    end

    # @overrides Nokogiri::XML::SAX::Document#end_element()
    def end_element(_name)
      @level -= 1
    end
  end

  # Template for creating client_stat
  class ClientStatTemplate
    attr_reader :jmeter_plan, :execution_cycle, :clusterable, :stat_file_paths
    attr_accessor :logger

    def initialize(new_jmeter_plan, new_execution_cycle, new_clusterable, new_stat_file_paths)
      @jmeter_plan = new_jmeter_plan
      @execution_cycle = new_execution_cycle
      @clusterable = new_clusterable
      @stat_file_paths = new_stat_file_paths
    end

    # @return [[Hailstorm::Model::ClientStat, String]] [client_stat, combined_file_path: nil]
    def create
      stat_file_path, combined = collate_stats
      client_stat = nil
      File.open(stat_file_path, 'r') do |file_io|
        client_stat = do_create_client_stat(file_io)
      end

      persist_jtl(client_stat, stat_file_path)

      tuple = [client_stat]
      tuple.push(stat_file_path) if combined
      tuple
    end

    private

    def collate_stats
      stat_file_path = stat_file_paths.first if stat_file_paths.size == 1
      stat_file_path ||= combine_stats
      [stat_file_path, stat_file_paths.size > 1]
    end

    # Combines two or more JTL files to create new JTL file with combined stats.
    def combine_stats
      file_unique_ids = [execution_cycle, jmeter_plan, clusterable].compact.map(&:id)
      combined_file_path = File.join(Hailstorm.workspace(execution_cycle.project.project_code).tmp_path,
                                     "results-#{file_unique_ids.join('-')}-all.jtl")

      write_combined_file(combined_file_path)
      combined_file_path
    end

    def write_combined_file(combined_file_path)
      xml_decl = '<?xml version="1.0" encoding="UTF-8"?>'
      test_results_start_tag = '<testResults version="1.2">'
      test_results_end_tag = '</testResults>'
      File.open(combined_file_path, 'w') do |combined_file|
        combined_file.puts xml_decl
        combined_file.puts test_results_start_tag

        stat_file_paths.each do |file_path|
          File.open(file_path, 'r') do |file|
            file.each_line do |line|
              if line[xml_decl].nil? && line[test_results_start_tag].nil? && line[test_results_end_tag].nil?
                combined_file.print(line)
              end
            end
          end
        end

        combined_file.puts test_results_end_tag
      end
    end

    def do_create_client_stat(io_like)
      client_stat = execution_cycle
                    .client_stats
                    .where(jmeter_plan_id: jmeter_plan.id,
                           clusterable_id: clusterable.id,
                           clusterable_type: clusterable.class.name,
                           threads_count: jmeter_plan.latest_threads_count)
                    .first_or_create!

      jtl_document = JtlDocument.new(Hailstorm::Model::PageStat, client_stat)
      jtl_parser = Nokogiri::XML::SAX::Parser.new(jtl_document)
      jtl_parser.parse(io_like)
      # save in db
      jtl_document.page_stats_map.values.each(&:save!)
      aggregate_samples_count = client_stat.page_stats.sum(:samples_count)
      update_aggregates(client_stat, aggregate_samples_count)
      client_stat.save!
      client_stat
    end

    # SAX parsing to update attributes
    def update_aggregates(client_stat, aggregate_samples_count)
      client_stat.aggregate_response_throughput = (aggregate_samples_count.to_f / client_stat.test_duration)
      client_stat.aggregate_ninety_percentile = client_stat.sample_response_times.quantile(90)
      client_stat.last_sample_at = Time.at(client_stat.sample_duration / 1000)
    end

    # persist file to db and remove file from fs
    def persist_jtl(client_stat, stat_file_path)
      logger&.info { "Persisting #{stat_file_path} to DB..." }
      Hailstorm::Model::JtlFile.persist_file(client_stat, stat_file_path)
    end
  end

  # Builder factory of graphs
  module GraphBuilderFactory

    def self.aggregate_graph(identifier:, working_path:, other_builder: nil)
      output_path = File.join(working_path, "aggregate_graph_#{identifier}")
      if other_builder
        other_builder.output_path = output_path
        other_builder
      else
        com.brickred.tsg.hailstorm.AggregateGraph.new(output_path)
      end
    end
  end

  private

  def build_threshold_matrix
    threshold_titles = JSON.parse(self.page_stats.first.samples_breakup_json)
                           .collect { |e| e['r'] }
                           .map
                           .with_index { |range, index| title_from_range(index, range) }

    threshold_data = self.page_stats
                         .collect(&:samples_breakup_json)
                         .collect { |json| JSON.parse(json).collect { |e| e['p'].to_f } }
                         .transpose
    [threshold_data, threshold_titles]
  end

  def title_from_range(index, range)
    if !range.is_a?(Array)
      index.zero? ? "Under #{range}s" : "Over #{range}s"
    else
      "#{range.first}s to #{range.last}s"
    end
  end

  def response_time_matrix
    self.page_stats.collect do |e|
      [e.minimum_response_time, e.maximum_response_time,
       e.average_response_time, e.ninety_percentile_response_time,
       e.median_response_time]
    end.transpose
  end

  def set_defaults
    self.sample_response_times = Hailstorm::Support::Quantile.new
  end
end
