# frozen_string_literal: true

# ExecutionCycle model
# @author Sayantam Dey

require 'nokogiri'
require 'zip/filesystem'

require 'hailstorm/model'
require 'hailstorm/model/project'
require 'hailstorm/model/master_agent'
require 'hailstorm/model/client_stat'
require 'hailstorm/model/target_stat'
require 'hailstorm/model/jmeter_plan'
require 'hailstorm/support/report_builder'
require 'hailstorm/support/collection_helper'

# This is a representation of one test run. A single test run can be as simple as one JMeter plan executed on a single
# cluster and more complicated with multiple JMeter plans and/or multiple clusters.
class Hailstorm::Model::ExecutionCycle < ActiveRecord::Base
  include Hailstorm::Support::CollectionHelper

  belongs_to :project

  has_many :client_stats, dependent: :destroy

  has_many :target_stats, dependent: :destroy

  before_create :set_defaults

  # @param [Hailstorm::Model::Project] project
  # @param [Array<Integer>] cycle_ids
  # @param [Hailstorm::Support::ReportBuilder] report_builder
  # @return [String] path to generated report
  def self.create_report(project, cycle_ids, report_builder = nil)
    reported_execution_cyles = self.execution_cycles_for_report(project, cycle_ids)
    if reported_execution_cyles.empty?
      logger.warn('No results to create a report')
      return
    end

    builder = report_builder || Hailstorm::Support::ReportBuilder.new
    generator = ReportGenerator.new(builder, project, reported_execution_cyles)
    generator.create # returns path to generated report
  end

  def self.execution_cycles_for_report(project, cycle_ids = nil)
    report_sequence_list = cycle_ids
    # all stopped tests unless specific sequence is needed
    conditions = { status: States::STOPPED } if report_sequence_list.blank?
    conditions ||= { id: report_sequence_list }

    project.execution_cycles.where(conditions).order(:started_at).all
  end

  def self.client_comparison_graph(execution_cycles, working_path:, width: 640, height: 600, builder: nil)
    grapher = ClientComparisonGraphBuilder.new(execution_cycles, builder: builder, working_path: working_path)
    grapher.build(width: width, height: height)
  end

  def self.cpu_comparison_graph(execution_cycles, working_path:, width: 640, height: 300, builder: nil)
    grapher = TargetComparisonGraphBuilder.new(execution_cycles, metric: :cpu, builder: builder,
                                                                 working_path: working_path)
    grapher.build(width: width, height: height, &:average_cpu_usage)
  end

  def self.memory_comparison_graph(execution_cycles, working_path:, width: 640, height: 300, builder: nil)
    grapher = TargetComparisonGraphBuilder.new(execution_cycles, metric: :memory, builder: builder,
                                                                 working_path: working_path)
    grapher.build(width: width, height: height, &:average_memory_usage)
  end

  # @return [String] started_at in YYYY-MM-DD HH:MM format
  def formatted_started_at
    self.started_at.strftime('%Y-%m-%d %H:%M')
  end

  # @return [String] stopped_at in YYYY-MM-DD HH:MM format
  def formatted_stopped_at
    self.stopped_at.strftime('%Y-%m-%d %H:%M')
  end

  # @return [Float] a rough cut average of 90 %tile response time across all client cycles
  def avg_90_percentile
    self.client_stats.average(:aggregate_ninety_percentile)
  end

  def avg_tps
    self.client_stats.average(:aggregate_response_throughput)
  end

  def target_hosts
    @target_hosts ||= self.target_stats.includes(:target_host).collect(&:target_host)
  end

  def clusters
    @clusters ||= self.client_stats
                      .group(:clusterable_id, :clusterable_type)
                      .select('clusterable_id, clusterable_type')
                      .order(:clusterable_type)
                      .collect { |cs| [cs.clusterable_id, cs.clusterable_type] }
                      .collect do |cs_item|

      require(cs_item.last.underscore) # require path form of the type (eg. hailstorm/model/amazon_cloud)
      clusterable_klass = cs_item.last.constantize
      clusterable_klass.find(cs_item.first) # find(id) method invoked
    end
  end

  def set_stopped_at
    self.update_attribute(:stopped_at, self.client_stats.maximum(:last_sample_at))
  end

  # Name of all JMeter plans for this execution cycle
  # @return [Array] (of Hailstorm::Model::JmeterPlan)
  def jmeter_plans
    jmeter_plan_ids = self.client_stats.collect(&:jmeter_plan_id).uniq
    Hailstorm::Model::JmeterPlan.where(id: jmeter_plan_ids)
  end

  # The duration of the execution cycle in HH:MM:SS format. If the cycle was
  # aborted/terminated, nil is returned.
  # @return [String]
  def execution_duration
    return nil if self.stopped_at.nil?

    duration_seconds = self.stopped_at - self.started_at
    dhc = duration_seconds / 3600 # hours component
    dhc_mod = duration_seconds % 3600
    dhm = dhc_mod / 60 # minutes component
    dhs = dhc_mod % 60 # seconds component
    format('%<hours>02d:%<minutes>02d:%<seconds>02d', { hours: dhc, minutes: dhm, seconds: dhs })
  end

  # Mark the execution cycle as started now or at given time
  # @param [Time] time
  def started!(time = nil)
    self.started_at = (time || Time.now) if self.started_at.nil?
  end

  def status
    value = read_attribute(:status)
    value.respond_to?(:to_sym) ? value.to_sym : value
  end

  # Mark the execution cycle as stopped
  def stopped!
    self.update_column(:status, States::STOPPED)
  end

  # Mark the execution cycle as aborted
  def aborted!
    self.update_column(:status, States::ABORTED)
  end

  def terminated!
    self.update_column(:status, States::TERMINATED)
  end

  def reported!
    self.update_column(:status, States::REPORTED)
  end

  def excluded!
    self.update_column(:status, States::EXCLUDED)
  end

  # Exports the results as one or more JTL files.
  # @return [Array<String>] Array of absolute path of exported files
  def export_results(export_dir_path)
    self.client_stats.map { |client_stat| client_stat.write_jtl(export_dir_path) }
  end

  # Import results from a JMeter results file (JTL)
  # @param [Hailstorm::Model::JmeterPlan] jmeter_plan
  # @param [Hailstorm::Behavior::Clusterable] cluster_instance
  # @param [String] result_file_path
  def import_results(jmeter_plan, cluster_instance, result_file_path)
    logger.debug { "#{self.class}.#{__method__}" }
    jmeter_plan.update_column(:latest_threads_count, jmeter_plan.num_threads)
    self.increment!(:threads_count, jmeter_plan.num_threads)
    client_stat, = Hailstorm::Model::ClientStat.create_client_stat(self, jmeter_plan.id,
                                                                   cluster_instance,
                                                                   [result_file_path])

    self.update!(started_at: client_stat.first_sample_at, stopped_at: client_stat.last_sample_at)
  end

  def aborted?
    self.status.to_s.to_sym == States::ABORTED
  end

  # Analysis of an execution cycle based on client statistics
  module ExecutionCycleAnalysis

    # Generates a hits per second graph
    def hits_per_second_graph(working_path:, width: 640, height: 300, builder: nil)
      sax_document = ResponseTimeFreqDist.new
      summarize_client_stats!(sax_document)

      grapher = GraphBuilderFactory.time_series_graph(series_name: 'Requests/second',
                                                      range_name: 'Requests',
                                                      start_time: sax_document.start_time,
                                                      other_builder: builder)
      sax_document.hit_matrix.each do |key, value|
        grapher.addDataPoint(key, value)
      end

      output_path = File.join(working_path, "hits_per_second_graph_#{self.id}")
      grapher.build(output_path, width, height)
    end

    def active_threads_over_time_graph(working_path:, width: 640, height: 300, builder: nil)
      sax_document = VirtualUserTimeDist.new
      summarize_client_stats!(sax_document)

      grapher = GraphBuilderFactory.time_series_graph(series_name: 'Virtual Users / Second',
                                                      range_name: 'Virtual Users',
                                                      start_time: sax_document.start_time,
                                                      other_builder: builder)

      sax_document.each_ts_vusers_count { |ts, threads_count| grapher.addDataPoint(ts, threads_count) }

      output_path = File.join(working_path, "vusers_per_second_graph_#{self.id}")
      grapher.build(output_path, width, height)
    end

    def throughput_over_time_graph(working_path:, width: 640, height: 300, builder: nil)
      sax_document = ThroughputTimeDist.new
      summarize_client_stats!(sax_document)

      grapher = GraphBuilderFactory.time_series_graph(series_name: 'Throughput over time',
                                                      range_name: 'Bytes Transferred',
                                                      start_time: sax_document.start_time,
                                                      other_builder: builder)
      sax_document.byte_matrix.each do |key, value|
        grapher.addDataPoint(key, value)
      end

      output_path = File.join(working_path, "throughput_per_second_graph_#{self.id}")
      grapher.build(output_path, width, height)
    end

    def add_domain_label(domain_labels)
      domain_label = self.threads_count.to_s
      # repeated total_threads_count(domain_label)
      domain_label.concat("-#{self.id}") if domain_labels.include?(domain_label)
      domain_labels.push(domain_label)
      domain_label
    end
  end

  include ExecutionCycleAnalysis

  # Generates the report from the builder and contextual objects
  class ReportGenerator
    attr_reader :builder, :project, :execution_cycles, :working_path

    # @param [Hailstorm::Support::ReportBuilder] new_builder
    # @param [Hailstorm::Model::Project] new_project
    # @param [Array<Hailstorm::Model::ExecutionCycle>] new_execution_cycles
    def initialize(new_builder, new_project, new_execution_cycles)
      @builder = new_builder
      @project = new_project
      @execution_cycles = new_execution_cycles
      @working_path = Hailstorm.workspace(@project.project_code)
                               .make_tmp_dir("#{@execution_cycles.first.id}-#{@execution_cycles.last.id}")
    end

    def create
      self.builder.title = project.title || project.project_code.humanize

      add_execution_cycles

      # adding aggregate graphs over all execution_cycles
      add_comparision_graphs unless execution_cycles.size == 1

      timestamp = Time.now.strftime('%Y%m%d%H%M%S')
      report_file_name = "#{project.project_code}-#{timestamp}" # minus extn

      self.builder.build(self.working_path, report_file_name) # returns path to generated file
    end

    private

    def add_execution_cycles
      execution_cycles.each do |execution_cycle|
        self.builder.jmeter_plans = execution_cycle.jmeter_plans
        add_test_summary(execution_cycle)

        self.builder.execution_detail_items do |execution_item|
          execution_item.total_threads_count = execution_cycle.threads_count
          add_clusters(execution_cycle, execution_item)
          add_time_series(execution_cycle, execution_item)
          add_target_stats(execution_cycle, execution_item)
        end
      end
    end

    def add_test_summary(execution_cycle)
      self.builder.test_summary_rows do |row|
        row.jmeter_plans = execution_cycle.jmeter_plans.collect(&:plan_name).join(', ')
        row.test_duration = execution_cycle.execution_duration
        row.total_threads_count = execution_cycle.threads_count
        row.target_hosts = execution_cycle.target_hosts
      end
    end

    def add_clusters(execution_cycle, execution_item)
      execution_cycle.clusters.each do |cluster|
        execution_item.clusters do |cluster_item|
          cluster_item.name = cluster.slug
          add_client_stats(cluster, cluster_item, execution_cycle)
        end
      end
    end

    def add_client_stats(cluster, cluster_item, execution_cycle)
      cluster
        .client_stats
        .where(execution_cycle_id: execution_cycle.id)
        .each do |client_stat|

        cluster_item.client_stats do |client_stat_item|
          client_stat_item.name = client_stat.jmeter_plan.plan_name
          client_stat_item.threads_count = client_stat.threads_count
          client_stat_item.aggregate_stats = client_stat.aggregate_stats
          client_stat_item.aggregate_graph do |g|
            g.chart_model = client_stat.aggregate_graph(working_path: self.working_path)
          end
        end
      end
    end

    def add_time_series(execution_cycle, execution_item)
      execution_item.hits_per_second_graph do |g|
        g.chart_model = execution_cycle.hits_per_second_graph(working_path: self.working_path)
      end
      execution_item.active_threads_over_time_graph do |g|
        g.chart_model = execution_cycle.active_threads_over_time_graph(working_path: self.working_path)
      end
      execution_item.throughput_over_time_graph do |g|
        g.chart_model = execution_cycle.throughput_over_time_graph(working_path: self.working_path)
      end
    end

    def add_target_stats(execution_cycle, execution_item)
      execution_cycle.target_stats.each do |target_stat|
        execution_item.target_stats do |target_stat_item|
          target_stat_item.role_name = target_stat.target_host.role_name
          target_stat_item.host_name = target_stat.target_host.host_name
          target_stat_item.utilization_graph do |g|
            g.chart_model = target_stat.utilization_graph(working_path: self.working_path)
          end
        end
      end
    end

    def add_comparision_graphs
      self.builder.client_comparison_graph do |graph|
        graph.chart_model = Hailstorm::Model::ExecutionCycle.client_comparison_graph(execution_cycles,
                                                                                     working_path: self.working_path)
      end

      self.builder.target_cpu_comparison_graph do |graph|
        graph.chart_model = Hailstorm::Model::ExecutionCycle.cpu_comparison_graph(execution_cycles,
                                                                                  working_path: self.working_path)
      end
      self.builder.target_memory_comparison_graph do |graph|
        graph.chart_model = Hailstorm::Model::ExecutionCycle.memory_comparison_graph(execution_cycles,
                                                                                     working_path: self.working_path)
      end
    end
  end

  # Builds client comparison graphs across execution cycles
  class ClientComparisonGraphBuilder

    attr_reader :execution_cycles, :grapher

    def initialize(execution_cycles, working_path:, builder: nil)
      @execution_cycles = execution_cycles
      @grapher = GraphBuilderFactory.client_comparison_graph(File.join(working_path, output_path),
                                                             other_builder: builder)
    end

    def build(width:, height:)
      # bug #Research-440
      # store the total_threads_count in a map such that if it is repeated for a
      # particular execution_cycle, the sequence Id is appended. This prevents the
      # points from collapsing in the graph.
      domain_labels = []
      execution_cycles.each do |execution_cycle|
        count_client_stats = 0
        agg_ninety_pctile_resp_time = 0.0
        agg_tps = 0.0

        execution_cycle.client_stats.each do |client_stat|
          count_client_stats += 1
          agg_ninety_pctile_resp_time += client_stat.aggregate_ninety_percentile
          agg_tps += client_stat.aggregate_response_throughput
        end

        execution_cycle_response_time = (agg_ninety_pctile_resp_time.to_f / count_client_stats).round(2)

        domain_label = execution_cycle.add_domain_label(domain_labels)

        grapher.addResponseTimeDataItem(domain_label, execution_cycle_response_time)

        execution_cycle_throughput = (agg_tps.to_f / count_client_stats).round(2)
        grapher.addThroughputDataItem(domain_label, execution_cycle_throughput)
      end

      grapher.build(width, height) # <-- returns path to generated image
    end

    private

    def output_path
      if @output_path.nil?
        start_id = execution_cycles.first.id
        end_id = execution_cycles.last.id
        @output_path = "client_execution_comparison_graph_#{start_id}-#{end_id}"
      end

      @output_path
    end
  end

  # Builds target comparison graphs across execution_cycles
  class TargetComparisonGraphBuilder

    attr_reader :execution_cycles, :metric, :grapher

    def initialize(execution_cycles, metric:, working_path:, builder: nil)
      @execution_cycles = execution_cycles
      @metric = metric
      @grapher = GraphBuilderFactory.target_comparison_graph(File.join(working_path, output_path),
                                                             metric: metric, other_builder: builder)
    end

    def build(width:, height:)
      # repeated total_threads_count cause a collapsed graph - bug #Research-440
      domain_labels = []
      execution_cycles.each do |execution_cycle|
        domain_label = execution_cycle.add_domain_label(domain_labels)
        execution_cycle.target_stats.includes(:target_host).each do |target_stat|
          data_point = yield target_stat
          grapher.addDataItem(data_point, target_stat.target_host.host_name, domain_label)
        end
      end

      grapher.build(width, height) unless domain_labels.empty?
    end

    private

    def output_path
      @output_path ||= "#{metric}_comparison_graph_#{execution_cycles.first.id}-#{execution_cycles.last.id}"
    end
  end

  # SAX document that calculates a response time frequency distribution
  class ResponseTimeFreqDist < Nokogiri::XML::SAX::Document
    attr_reader :hit_matrix, :start_time

    def start_document
      @level = 0
      @hit_matrix = {} if @hit_matrix.nil?
    end

    def start_element(name, attrs = [])
      return unless %w[httpSample sample].include?(name)

      @level += 1
      attrs_map = Hash[attrs]
      tms = attrs_map['ts'].to_i # ms
      update_matrix(tms)
    end

    def end_element(name)
      return unless %w[httpSample sample].include?(name)

      @level -= 1
      @parent_ts = nil if @level.zero?
    end

    private

    def update_matrix(tms)
      ts = tms / 1000 # sec
      @hit_matrix[ts] = @hit_matrix[ts].to_i + 1 if @parent_ts.nil? || (@parent_ts != ts)
      @parent_ts = ts if @level == 1
      @start_time = tms if @start_time.nil? || (@start_time > tms)
    end
  end

  # Creates a virtual users distribution over time
  class VirtualUserTimeDist < Nokogiri::XML::SAX::Document
    attr_reader :vusers_matrix, :start_time

    def start_document
      @vusers_matrix = {} if @vusers_matrix.nil?
      @start_time = nil
      @host_matrix = {} if @host_matrix.nil?
    end

    def start_element(name, attrs = [])
      return unless %w[httpSample sample].include?(name)

      attrs_map = Hash[attrs]
      tms = attrs_map['ts'].to_i # ms
      ts = tms / 1000 # sec
      num_active_threads = attrs_map['na'].to_i

      if num_active_threads.positive?
        host_name = attrs_map['hn']
        update_matrices(host_name, num_active_threads, ts)
      end

      @start_time = tms if @start_time.nil? || (@start_time > tms)
    end

    def each_ts_vusers_count
      ts_keys = vusers_matrix.keys.sort_by(&:to_i)
      ts_keys.each_with_index do |ts, index|
        previous_index = index > 1 ? index - 1 : index
        next_index = index < ts_keys.size - 1 ? index + 1 : index
        previous_count = vusers_matrix[ts_keys[previous_index]]
        threads_count = vusers_matrix[ts]
        next_count = vusers_matrix[ts_keys[next_index]]
        if (previous_count == next_count) && (previous_count > threads_count)
          threads_count = previous_count # dip correction
        end

        yield(ts, threads_count)
      end
    end

    private

    def update_matrices(host_name, num_active_threads, timestamp)
      @host_matrix[timestamp] = [] if @host_matrix[timestamp].nil?
      if !@host_matrix[timestamp].include?(host_name)
        @vusers_matrix[timestamp] = @vusers_matrix[timestamp].to_i + num_active_threads
      elsif @vusers_matrix[timestamp].to_i < num_active_threads
        @vusers_matrix[timestamp] = num_active_threads
      end
      @host_matrix[timestamp].push(host_name) unless @host_matrix[timestamp].include?(host_name)
    end
  end

  # Creates throughput distribution over time
  class ThroughputTimeDist < Nokogiri::XML::SAX::Document
    attr_reader :byte_matrix, :start_time

    def start_document
      @level = 0
      @byte_matrix = {} if @byte_matrix.nil?
    end

    def start_element(name, attrs = [])
      return unless %w[httpSample sample].include?(name)

      if @level.zero?
        attrs_map = Hash[attrs]
        tms = attrs_map['ts'].to_i # ms
        ts = tms / 1000 # sec
        @byte_matrix[ts] = @byte_matrix[ts].to_i + attrs_map['by'].to_i
        @start_time = tms if @start_time.nil? || (@start_time > tms)
      end
      @level += 1
    end

    def end_element(name)
      @level -= 1 if %w[httpSample sample].include?(name)
    end
  end

  # Factory module for graph builders
  module GraphBuilderFactory

    def self.target_comparison_graph(output_path, metric:, other_builder: nil)
      if other_builder.nil?
        grapher_klass = com.brickred.tsg.hailstorm.TargetComparisonGraph
        case metric
        when :cpu
          grapher_klass.getCpuComparisionBuilder(output_path)
        when :memory
          grapher_klass.getMemoryComparisionBuilder(output_path)
        else
          raise(ArgumentError, 'metric must be either :cpu or :memory')
        end
      else
        other_builder.output_path = output_path
        other_builder
      end
    end

    def self.client_comparison_graph(output_path, other_builder: nil)
      if other_builder
        other_builder.output_path = output_path
        other_builder
      else
        com.brickred.tsg.hailstorm.ExecutionComparisonGraph.new(output_path)
      end
    end

    def self.time_series_graph(series_name:, range_name:, start_time:, other_builder: nil)
      if other_builder
        other_builder.series_name = series_name
        other_builder.range_name = range_name
        other_builder.start_time = start_time
        other_builder
      else
        com.brickred.tsg.hailstorm.TimeSeriesGraph.new(series_name, range_name, start_time)
      end
    end
  end

  private

  # Parses the JTL file and streams it back to summarize as per the SAX document. The document object is mutated.
  def summarize_client_stats!(sax_document)
    sax_parser = Nokogiri::XML::SAX::Parser.new(sax_document)
    self.client_stats.each do |client_stat|
      export_file = client_stat.write_jtl(Hailstorm.workspace(self.project.project_code).tmp_path, append_id: true)
      File.open(export_file, 'r') do |file|
        sax_parser.parse(file)
      end
    end
  end

  def set_defaults
    started!
    self.status ||= States::STARTED
  end

  class States
    STARTED = :started
    STOPPED = :stopped
    ABORTED = :aborted
    TERMINATED = :terminated
    REPORTED = :reported
    EXCLUDED = :excluded
  end
end
