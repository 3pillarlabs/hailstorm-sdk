#
# @author Sayantam Dey

require 'nokogiri'

require 'hailstorm/model'
require 'hailstorm/model/execution_cycle'
require 'hailstorm/model/jmeter_plan'
require 'hailstorm/model/page_stat'
require 'hailstorm/model/jtl_file'
require 'hailstorm/support/quantile'

class Hailstorm::Model::ClientStat < ActiveRecord::Base

  belongs_to :execution_cycle

  belongs_to :jmeter_plan

  belongs_to :clusterable, :polymorphic => true

  has_many :page_stats, :dependent => :destroy

  has_many :jtl_files, :dependent => :delete_all

  # starting (minimum) timestamp of collected samples
  attr_accessor :start_timestamp

  # last sample collected
  attr_accessor :end_sample

  # Array to store 90% response time of all samples
  attr_accessor :sample_response_times

  after_initialize :set_defaults

  def self.create_client_stats(execution_cycle, jmeter_plan_id,
      clusterable, stat_file_paths, rm_stat_file = true)

    # Collate statistics file if needed
    stat_file_path = nil
    if stat_file_paths.size == 1
      stat_file_path = stat_file_paths.first
    else
      stat_file_path = combine_stats(stat_file_paths, execution_cycle.id,
                                     jmeter_plan_id, clusterable.id)
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

    logger.debug { "Calculating aggregate_ninety_percentile..." }
    client_stat.aggregate_ninety_percentile = client_stat.sample_response_times.quantile(90)
    logger.debug { "... finished calculating aggregate_ninety_percentile" }

    # this is the duration of the last sample sent, it is in milliseconds, so
    # we divide it by 1000
    client_stat.last_sample_at = Time.at((client_stat.end_sample['ts'].to_i +
        client_stat.end_sample['t'].to_i) / 1000)

    client_stat.save!

    # persist file to DB and remove file from FS
    logger.info { "Persisting #{stat_file_path} to DB..." }
    Hailstorm::Model::JtlFile.persist_file(client_stat, stat_file_path)
    File.unlink(stat_file_path) if rm_stat_file
    client_stat
  end

  # Combines two or more JTL files to create new JTL file with combined stats.
  # The path to full file is returned.
  # @param [Array] stat_file_paths path to JTL files
  # @param [Integer] execution_cycle_id
  # @param [Integer]jmeter_plan_id
  # @param [Integer] clusterable_id ID
  # @param [Boolean] unlink_stat_files remove the stat files after combining them
  # @return [String] path to new file
  def self.combine_stats(stat_file_paths, execution_cycle_id,
      jmeter_plan_id = nil, clusterable_id = nil, unlink_stat_files = true)

    xml_decl = '<?xml version="1.0" encoding="UTF-8"?>'
    test_results_start_tag = '<testResults version="1.2">'
    test_results_end_tag = '</testResults>'
    file_unique_ids = [execution_cycle_id]
    file_unique_ids.push(jmeter_plan_id) unless jmeter_plan_id.nil?
    file_unique_ids.push(clusterable_id) unless clusterable_id.nil?
    combined_file_path = File.join(Hailstorm.tmp_path,
      "results-#{file_unique_ids.join('-')}-all.jtl")

    unless File.exists?(combined_file_path)
      File.open(combined_file_path, 'w') do |combined_file|
        combined_file.puts xml_decl
        combined_file.puts test_results_start_tag

        stat_file_paths.each do |file_path|
          File.open(file_path, 'r') do |file|
            file.each_line do |line|
              if line[xml_decl].nil? and line[test_results_start_tag].nil? and line[test_results_end_tag].nil?
                combined_file.print(line)
              end
            end
          end
        end

        combined_file.puts test_results_end_tag
      end

      # remove individual files
      if unlink_stat_files
        stat_file_paths.each do |file_path|
          File.unlink(file_path)
        end
      end
    end

    return combined_file_path
  end

  # @return [String] path to generated image
  def aggregate_graph()

    page_labels = self.page_stats()
                      .collect(&:page_label)

    response_times = self.page_stats.collect {|e|
      [e.minimum_response_time, e.maximum_response_time,
        e.average_response_time, e.ninety_percentile_response_time,
        e.median_response_time]
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

    error_percentages = self.page_stats()
                            .collect(&:percentage_errors)

    grapher = com.brickred.tsg.hailstorm.AggregateGraph.new(aggregate_graph_path)
    grapher.setPages(page_labels)
           .setNinetyCentileResponseTimes(response_times[3])
           .setThresholdTitles(threshold_titles)
           .setThresholdData(threshold_data)
           .setErrorPercentages(error_percentages)
           .create() # <-- returns path to generated image
                     #.setMinResponseTimes(response_times[0])
                     #.setMaxResponseTimes(response_times[1])
                     #.setAvgResponseTimes(response_times[2])
                     #.setMedianResponseTimes(response_times[4])
  end

  def aggregate_stats()
    self.page_stats()
        .collect(&:stat_item)
  end

  def self.execution_comparison_graph(execution_cyles)

    grapher_klass = com.brickred.tsg.hailstorm.ExecutionComparisonGraph
    grapher = grapher_klass.new(execution_comparison_graph_path(execution_cyles))

    # bug #Research-440
    # store the total_threads_count in a map such that if it is repeated for a
    # particular execution_cycle, the sequence Id is appended. This prevents the
    # points from collapsing in the graph.
    domain_labels = []
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

      domain_label = execution_cycle.total_threads_count().to_s
      if domain_labels.include?(domain_label) # repeated total_threads_count(domain_label)
        domain_label.concat("-#{execution_cycle.id}")
      end
      domain_labels.push(domain_label)

      grapher.addResponseTimeDataItem(domain_label,
                                      execution_cycle_response_time)

      execution_cycle_throughput = (total_transactions_per_second.to_f /
          count_client_stats).round(2)
      grapher.addThroughputDataItem(domain_label,
                                    execution_cycle_throughput)
    end

    grapher.build(640, 600) # <-- returns path to generated image
  end

  def collect_sample(sample)

    sample_timestamp = sample['ts'].to_f

    # start_timestamp
    if self.start_timestamp.nil? or sample_timestamp < self.start_timestamp
      self.start_timestamp = sample_timestamp
    end

    # end_sample
    if self.end_sample.nil? or sample_timestamp > self.end_sample['ts'].to_f
      self.end_sample = sample
    end

    self.sample_response_times.push(sample['t'])
  end

  # @param [String] export_dir directory for exported files
  # @return [String] path to exported file
  def write_jtl(export_dir, append_id = false)
    require(self.clusterable_type.underscore)
    file_name = [self.clusterable.slug.gsub(/[\W\s]+/, '_'),
                 self.jmeter_plan.test_plan_name.gsub(/[\W\s]+/, '_')].join('-')
    file_name.concat("-#{self.id}") if append_id
    file_name.concat(".jtl")

    export_file = File.join(export_dir, file_name)
    Hailstorm::Model::JtlFile.export_file(self, export_file) unless File.exists?(export_file)
    return export_file
  end

  # Generates a hits per second graph
  def self.hits_per_second_graph(execution_cycle)
    sax_document = Nokogiri::XML::SAX::Document.new()
    sax_document.class_eval do
      attr_reader :hit_matrix
      attr_reader :start_time

      def start_document()
        @level = 0
        @hit_matrix = {} if @hit_matrix.nil?
      end

      def start_element(name, attrs = [])
        if %w(httpSample sample).include?(name)
          @level += 1
          attrs_map = Hash[attrs]
          tms = attrs_map['ts'].to_i # ms
          ts = tms / 1000 # sec
          if @parent_ts.nil? or @parent_ts != ts
            @hit_matrix[ts] = @hit_matrix[ts].to_i + 1
          end
          @parent_ts = ts if @level == 1
          @start_time = tms if @start_time.nil? or @start_time > tms
        end
      end

      def end_element(name)
        if %w(httpSample sample).include?(name)
          @level -= 1
          @parent_ts = nil if @level == 0
        end
      end
    end
    sax_parser = Nokogiri::XML::SAX::Parser.new(sax_document)
    execution_cycle.client_stats.each do |client_stat|
      export_file = client_stat.write_jtl(Hailstorm.tmp_path, true)
      File.open(export_file, 'r') do |file|
        sax_parser.parse(file)
      end
    end

    grapher = com.brickred.tsg.hailstorm.TimeSeriesGraph.new("Requests/second",
                                                             "Requests",
                                                             sax_document.start_time)
    sax_document.hit_matrix.each do |key, value|
      grapher.addDataPoint(key, value)
    end

    grapher.build(File.join(Hailstorm.root, Hailstorm.reports_dir,
                            "hits_per_second_graph_#{execution_cycle.id}"), 640, 300)
  end

  def self.active_threads_over_time_graph(execution_cycle)
    sax_document = Nokogiri::XML::SAX::Document.new()
    sax_document.class_eval do
      attr_reader :vusers_matrix
      attr_reader :start_time

      def start_document()
        @vusers_matrix = {} if @vusers_matrix.nil?
        @start_time = nil
        @host_matrix = {} if @host_matrix.nil?
      end

      def start_element(name, attrs = [])
        if %w(httpSample sample).include?(name)
          attrs_map = Hash[attrs]
          tms = attrs_map['ts'].to_i # ms
          ts = tms / 1000 # sec
          num_active_threads = attrs_map['na'].to_i

          if num_active_threads > 0
            host_name = attrs_map['hn']
            @host_matrix[ts] = [] if @host_matrix[ts].nil?
            if !@host_matrix[ts].include?(host_name)
              @vusers_matrix[ts] = @vusers_matrix[ts].to_i + num_active_threads
            elsif @vusers_matrix[ts].to_i < num_active_threads
              @vusers_matrix[ts] = num_active_threads
            end
            @host_matrix[ts].push(host_name) unless @host_matrix[ts].include?(host_name)
          end

          @start_time = tms if @start_time.nil? or @start_time > tms
        end
      end

    end
    sax_parser = Nokogiri::XML::SAX::Parser.new(sax_document)

    execution_cycle.client_stats.each do |client_stat|
      export_file = client_stat.write_jtl(Hailstorm.tmp_path, true)
      File.open(export_file, 'r') do |file|
        sax_parser.parse(file)
      end
    end

    grapher = com.brickred.tsg.hailstorm.TimeSeriesGraph.new("Virtual Users / Second",
                                                             "Virtual Users",
                                                             sax_document.start_time)
    ts_keys = sax_document.vusers_matrix.keys.sort {|a,b| a.to_i <=> b.to_i}
    ts_keys.each_with_index do |ts, index|
      previous_index = index > 1 ? index - 1 : index
      next_index = index < ts_keys.size - 1 ? index + 1 : index
      previous_count = sax_document.vusers_matrix[ts_keys[previous_index]]
      threads_count = sax_document.vusers_matrix[ts]
      next_count = sax_document.vusers_matrix[ts_keys[next_index]]
      if previous_count == next_count and previous_count > threads_count
        threads_count = previous_count # dip correction
      end
      grapher.addDataPoint(ts, threads_count)
    end
    grapher.build(File.join(Hailstorm.root, Hailstorm.reports_dir,
                            "vusers_per_second_graph_#{execution_cycle.id}"), 640, 300)
  end

  def self.throughput_over_time_graph(execution_cycle)
    sax_document = Nokogiri::XML::SAX::Document.new()
    sax_document.class_eval do
      attr_reader :byte_matrix
      attr_reader :start_time

      def start_document()
        @level = 0
        @byte_matrix = {} if @byte_matrix.nil?
      end

      def start_element(name, attrs = [])
        if %w(httpSample sample).include?(name)
          if @level == 0
            attrs_map = Hash[attrs]
            tms = attrs_map['ts'].to_i # ms
            ts = tms / 1000 # sec
            @byte_matrix[ts] = @byte_matrix[ts].to_i + attrs_map['by'].to_i
            @start_time = tms if @start_time.nil? or @start_time > tms
          end
          @level += 1
        end
      end

      def end_element(name)
        if %w(httpSample sample).include?(name)
          @level -= 1
        end
      end
    end
    sax_parser = Nokogiri::XML::SAX::Parser.new(sax_document)
    execution_cycle.client_stats.each do |client_stat|
      export_file = client_stat.write_jtl(Hailstorm.tmp_path, true)
      File.open(export_file, 'r') do |file|
        sax_parser.parse(file)
      end
    end

    grapher = com.brickred.tsg.hailstorm.TimeSeriesGraph.new("Throughput over time",
                                                             "Bytes Transferred",
                                                             sax_document.start_time)
    sax_document.byte_matrix.each do |key, value|
      grapher.addDataPoint(key, value)
    end

    grapher.build(File.join(Hailstorm.root, Hailstorm.reports_dir,
                            "throughput_per_second_graph_#{execution_cycle.id}"), 640, 300)
  end

  def first_sample_at
    Time.at((self.start_timestamp / 1000).to_i) if self.start_timestamp
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
    # @param [String] name
    # @param [Array] attrs
    def start_element(name, attrs = [])

      # check for level 1 because we don't collect sub-samples
      if @level == 1 and %w(httpSample sample).include?(name)
        attrs_map = Hash[attrs] # convert array of 2 element arrays to Hash
        label = attrs_map['lb'].strip()
        unless @page_stats_map.has_key?(label)
          @page_stats_map[label] = @stat_klass.new(:page_label => label,
                                                   :client_stat_id => @client_stat.id)
        end
        @client_stat.collect_sample(attrs_map)
        @page_stats_map[label].collect_sample(attrs_map)
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
    self.sample_response_times = Hailstorm::Support::Quantile.new()
  end

end
