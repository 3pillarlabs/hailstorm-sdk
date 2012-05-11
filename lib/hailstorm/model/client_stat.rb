#
# @author Sayantam Dey

require 'nokogiri'

require 'hailstorm/model'
require 'hailstorm/model/execution_cycle'
require 'hailstorm/model/jmeter_plan'
require 'hailstorm/model/page_stat'

class Hailstorm::Model::ClientStat < ActiveRecord::Base

  belongs_to :execution_cycle

  belongs_to :jmeter_plan

  belongs_to :clusterable, :polymorphic => true

  has_many :page_stats, :dependent => :destroy

  # starting (minimum) timestamp of collected samples
  attr_accessor :start_timestamp

  # last sample collected
  attr_accessor :end_sample

  # Array to store 90% response time of all samples
  attr_accessor :sample_response_times

  after_initialize :set_defaults

  def self.create_client_stats(execution_cycle, jmeter_plan_id,
                                  clusterable, stat_file_paths)

    # Collate statistics file if needed
    stat_file_path = nil
    if stat_file_paths.size == 1
      stat_file_path = stat_file_paths.first
    else
      stat_file_path = combine_stats(stat_file_paths, execution_cycle.id, jmeter_plan_id)
    end

    # create 1 record for client_stats if it does not exist yet
    jmeter_plan = Hailstorm::Model::JmeterPlan.find(jmeter_plan_id)
    client_stat = execution_cycle.client_stats()
                                 .where(:jmeter_plan_id => jmeter_plan.id,
                                    :clusterable_id => clusterable.id,
                                    :clusterable_type => clusterable.class.name,
                                    :threads_count => jmeter_plan.latest_threads_count)
                                 .first_or_create!()

    # SAX parsing
    jtl_document = JtlDocument.new(Hailstorm::Model::PageStat, client_stat)
    jtl_parser = Nokogiri::XML::SAX::Parser.new(jtl_document)
    File.open(stat_file_path, 'r') do |file|
      jtl_parser.parse(file)
    end

    # save in db
    jtl_document.page_stats_map.values.each do |page_stat|
      page_stat.save!
    end

    # update aggregates
    aggregate_samples_count = client_stat.page_stats()
                                         .sum(:samples_count)
    test_duration = (client_stat.end_sample['ts'].to_f +
        client_stat.end_sample['t'].to_f - client_stat.start_timestamp) / 1000.to_f

    client_stat.aggregate_response_throughput = (aggregate_samples_count.to_f / test_duration)

    client_stat.sample_response_times.sort!
    ninety_percentile_index = (aggregate_samples_count * 0.9).to_i - 1
    client_stat.aggregate_ninety_percentile = client_stat.sample_response_times[ninety_percentile_index]

    client_stat.save!

    File.unlink(stat_file_path) # remove file
  end

  # Combines two or more JTL files to create new JTL file with combined stats.
  # The path to full file is returned.
  # @param [Array] stat_file_paths path to JTL files
  # @param [Integer] execution_cycle_id
  # @param [Integer]jmeter_plan_id
  # @return [String] path to new file
  def self.combine_stats(stat_file_paths, execution_cycle_id, jmeter_plan_id)

    combined_file_path = File.join(Hailstorm.root, Hailstorm.log_dir,
      "results-#{execution_cycle_id}-#{jmeter_plan_id}-all.jtl")
    File.open(combined_file_path, 'w') do |combined_file|
      combined_file.puts '<?xml version="1.0" encoding="UTF-8"?>'
      combined_file.puts '<testResults version="1.2">'

      stat_file_paths.each do |file_path|
        File.open(file_path, 'r') do |file|
          file.each_line do |line|
            combined_file.print(line) unless line['httpSample'].nil?
          end
        end
      end

      combined_file.puts '</testResults>'
    end

    # remove individual files
    stat_file_paths.each do |file_path|
      File.unlink(file_path)
    end

    return combined_file_path
  end

  # @return [String] path to generated image
  def aggregate_graph()

    page_labels = self.page_stats.collect(&:page_label)

    response_times = self.page_stats.collect {|e|
      [e.minimum_response_time, e.maximum_response_time,
        e.average_response_time, e.ninety_percentile_response_time]
    }.transpose()

    threshold_titles = []
    JSON.parse(self.page_stats.first.samples_breakup_json)
        .collect {|e| e['r']}
        .each_with_index do |range, index|

      title = nil
      unless range.is_a?(Array)
        if 0 == index
          title = "Under #{range}s"
        else
          title = "Over #{range}s"
        end
      else
        title = "#{range.first}s to #{range.last}s"
      end
      threshold_titles.push(title)
    end

    threshold_data = self.page_stats()
                         .collect(&:samples_breakup_json)
                         .collect {|json| JSON.parse(json).collect {|e| e['p'].to_f}}
                         .transpose()

    grapher = com.brickred.tsg.hailstorm.AggregateGraph.new(aggregate_graph_path)
    grapher.setPages(page_labels)
           .setResponseTimes(response_times)
           .setThresholdTitles(threshold_titles)
           .setThresholdData(threshold_data)
           .create() # <-- returns path to generated image
  end

  def self.execution_comparison_graph(execution_cyles)

    grapher_klass = com.brickred.tsg.hailstorm.ExecutionComparisonGraph
    grapher = grapher_klass.new(execution_comparison_graph_path(execution_cyles))

    execution_cyles.each do |execution_cycle|
      count_client_stats = 0
      total_ninety_percentile_response_time = 0.0
      total_transactions_per_second = 0.0
      execution_cycle.client_stats.each do |client_stat|
        count_client_stats += 1
        total_ninety_percentile_response_time += client_stat.aggregate_ninety_percentile
        total_transactions_per_second += client_stat.aggregate_response_throughput
      end

      execution_cycle_response_time = (total_ninety_percentile_response_time.to_f /
          count_client_stats).round(2)
      grapher.addResponseTimeDataItem(execution_cycle.total_threads_count(),
                                      execution_cycle_response_time)

      execution_cycle_throughput = (total_transactions_per_second.to_f /
          count_client_stats).round(2)
      grapher.addThroughputDataItem(execution_cycle.total_threads_count(),
                                    execution_cycle_throughput)
    end

    grapher.build() # <-- returns path to generated image
  end

  def collect(sample)

    sample_timestamp = sample['ts'].to_f

    # start_timestamp
    if self.start_timestamp.nil? or sample_timestamp < self.start_timestamp
      self.start_timestamp = sample_timestamp
    end

    # end_sample
    if self.end_sample.nil? or sample_timestamp > self.end_sample['ts'].to_f
      self.end_sample = sample
    end

    self.sample_response_times.push(sample['t'].to_f)
  end

  # Receives event callbacks as XML is parsed
  class JtlDocument < Nokogiri::XML::SAX::Document

    attr_reader :page_stats_map

    def initialize(stat_klass, client_stat)

      @stat_klass = stat_klass
      @client_stat = client_stat
      @page_stats_map = {}
      @level = 0
    end

    # @overrides Nokogiri::XML::SAX::Document#start_element()
    def start_element(name, attrs = [])

      if @level == 1 and name == 'httpSample' # don't collect sub-samples
        attrs_map = Hash[attrs] # convert array of 2 element arrays to Hash
        label = attrs_map['lb']
        unless @page_stats_map.has_key?(label)
          @page_stats_map[label] = @stat_klass.new(:page_label => label,
                                                   :client_stat_id => @client_stat.id)
        end
        @client_stat.collect(attrs_map)
        @page_stats_map[label].collect(attrs_map)
      end
      @level += 1
    end

    # @overrides Nokogiri::XML::SAX::Document#end_element()
    def end_element(name)
      @level -= 1
    end
  end

  private

  def aggregate_graph_path()
    File.join(Hailstorm.root, Hailstorm.reports_dir, "aggregate_graph_#{self.id}")
  end

  def self.execution_comparison_graph_path(execution_cyles)

    start_id = execution_cyles.first.id
    end_id = execution_cyles.last.id
    File.join(Hailstorm.root, Hailstorm.reports_dir,
              "client_execution_comparison_graph_#{start_id}-#{end_id}")
  end

  def set_defaults()
    self.sample_response_times = []
  end

end
