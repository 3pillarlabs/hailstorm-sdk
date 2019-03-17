#
# ExecutionCycle model
# @author Sayantam Dey

require 'erubis/engine/eruby'
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

  # Generates the report from the builder and contextual objects
  class ReportGenerator
    attr_reader :builder, :project, :execution_cycles

    # @param [Hailstorm::Support::ReportBuilder] new_builder
    # @param [Hailstorm::Model::Project] new_project
    # @param [Array<Hailstorm::Model::ExecutionCycle>] new_execution_cycles
    def initialize(new_builder, new_project, new_execution_cycles)
      @builder = new_builder
      @project = new_project
      @execution_cycles = new_execution_cycles
    end

    def create
      builder.title = project.project_code.humanize

      add_execution_cycles

      # adding aggregate graphs over all execution_cycles
      add_comparision_graphs unless execution_cycles.size == 1

      reports_path = File.join(Hailstorm.root, Hailstorm.reports_dir)
      timestamp = Time.now.strftime('%Y%m%d%H%M%S')
      report_file_name = "#{project.project_code}-#{timestamp}" # minus extn

      builder.build(reports_path, report_file_name) # returns path to generated file
    end

    private

    def add_execution_cycles
      execution_cycles.each do |execution_cycle|
        builder.jmeter_plans = execution_cycle.jmeter_plans
        add_test_summary(execution_cycle)

        builder.execution_detail_items do |execution_item|
          execution_item.total_threads_count = execution_cycle.total_threads_count
          add_clusters(execution_cycle, execution_item)
          add_time_series(execution_cycle, execution_item)
          add_target_stats(execution_cycle, execution_item)
        end
      end
    end

    def add_test_summary(execution_cycle)
      builder.test_summary_rows do |row|
        row.jmeter_plans = execution_cycle.jmeter_plans.collect(&:plan_name).join(', ')
        row.test_duration = execution_cycle.execution_duration
        row.total_threads_count = execution_cycle.total_threads_count
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
            g.chart_model = client_stat.aggregate_graph
          end
        end
      end
    end

    def add_time_series(execution_cycle, execution_item)
      execution_item.hits_per_second_graph do |g|
        g.chart_model = Hailstorm::Model::ClientStat.hits_per_second_graph(execution_cycle)
      end
      execution_item.active_threads_over_time_graph do |g|
        g.chart_model = Hailstorm::Model::ClientStat.active_threads_over_time_graph(execution_cycle)
      end
      execution_item.throughput_over_time_graph do |g|
        g.chart_model = Hailstorm::Model::ClientStat.throughput_over_time_graph(execution_cycle)
      end
    end

    def add_target_stats(execution_cycle, execution_item)
      execution_cycle.target_stats.each do |target_stat|
        execution_item.target_stats do |target_stat_item|
          target_stat_item.role_name = target_stat.target_host.role_name
          target_stat_item.host_name = target_stat.target_host.host_name
          target_stat_item.utilization_graph do |g|
            g.chart_model = target_stat.utilization_graph
          end
        end
      end
    end

    def add_comparision_graphs
      builder.client_comparison_graph do |graph|
        graph.chart_model = Hailstorm::Model::ClientStat.execution_comparison_graph(execution_cycles)
      end

      builder.target_cpu_comparison_graph do |graph|
        graph.chart_model = Hailstorm::Model::TargetStat.cpu_comparison_graph(execution_cycles)
      end
      builder.target_memory_comparison_graph do |graph|
        graph.chart_model = Hailstorm::Model::TargetStat.memory_comparison_graph(execution_cycles)
      end
    end
  end

  # @param [Hailstorm::Model::Project] project
  # @param [Array<Integer>] cycle_ids
  # @param [Hailstorm::Support::ReportBuilder] report_builder
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

  # @return [String] started_at in YYYY-MM-DD HH:MM format
  def formatted_started_at
    self.started_at.strftime('%Y-%m-%d %H:%M')
  end

  # @return [String] stopped_at in YYYY-MM-DD HH:MM format
  def formatted_stopped_at
    self.stopped_at.strftime('%Y-%m-%d %H:%M')
  end

  # @return [Integer] sum of thread_counts in client_stats for this execution_cycle
  def total_threads_count
    @total_threads_count ||= self.client_stats.sum(:threads_count)
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
    format('%02d:%02d:%02d', dhc, dhm, dhs)
  end

  # Mark the execution cycle as started now or at given time
  # @param [Time] time
  def started!(time = nil)
    self.started_at = time || Time.now
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

  # Exports the results as one or more JTL files
  # @@return [Array] path to the files
  def export_results
    export_dir = File.join(Hailstorm.root, Hailstorm.reports_dir, "SEQUENCE-#{self.id}")
    FileUtils.rm_rf(export_dir)
    FileUtils.mkpath(export_dir)
    self.client_stats.map { |client_stat| client_stat.write_jtl(export_dir) }
  end

  # Import results from a JMeter results file (JTL)
  # @param [Hailstorm::Model::JmeterPlan] jmeter_plan
  # @param [Hailstorm::Behavior::Clusterable] cluster_instance
  # @param [String] result_file_path
  def import_results(jmeter_plan, cluster_instance, result_file_path)
    logger.debug { "#{self.class}.#{__method__}" }
    jmeter_plan.update_column(:latest_threads_count, jmeter_plan.num_threads)
    client_stat = Hailstorm::Model::ClientStat.create_client_stat(self, jmeter_plan.id,
                                                                  cluster_instance,
                                                                  [result_file_path],
                                                                  false)

    self.update_attributes!(started_at: client_stat.first_sample_at, stopped_at: client_stat.last_sample_at)
  end

  private

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
