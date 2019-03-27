require 'hailstorm/model'
require 'hailstorm/model/client_stat'
require 'hailstorm/support/quantile'

# A PageStat is the statistics for a sampler.
# @author Sayantam Dey
class Hailstorm::Model::PageStat < ActiveRecord::Base
  belongs_to :client_stat

  attr_accessor :cumulative_response_time

  attr_accessor :cumulative_squared_response_time

  attr_accessor :page_sample_times

  attr_accessor :min_start_time

  attr_accessor :max_end_time

  attr_accessor :cumulative_bytes

  attr_accessor :errors_count

  after_initialize :set_defaults

  before_create :calculate_aggregates

  # @param [Hash] sample keys same as httpSample attributes
  def collect_sample(sample)
    self.increment(:samples_count)

    sample_response_time = sample['t'].to_i
    calc_response_time_facts(sample_response_time)

    sample_start_time = sample['ts'].to_i
    calc_stat_duration(sample_response_time, sample_start_time)

    self.cumulative_bytes += sample['by'].to_i

    self.samples_breakup(sample_response_time)

    # 's' is either "true" or "false"
    sample_success = sample['s'] == true.to_s
    self.errors_count += 1 unless sample_success
  end

  def samples_breakup(sample_response_time = nil)
    @samples_breakup ||= init_samples_breakup
    update_samples_breakup(sample_response_time) unless sample_response_time.nil?
    @samples_breakup
  end

  def stat_item
    OpenStruct.new(self.attributes
                       .symbolize_keys
                       .except(:id, :client_stat_id, :samples_breakup_json))
  end

  private

  def update_samples_breakup(sample_response_time)
    srt_seconds = (sample_response_time.to_f / 1000)
    partition_to_update = nil
    @samples_breakup.each do |partition|
      partition_to_update = find_partition(srt_seconds, partition)
      break if partition_to_update
    end

    partition_to_update[:c] += 1
  end

  def find_partition(srt_seconds, partition)
    partition_to_update = nil
    range = partition[:r]
    if !range.is_a?(Array)
      partition_to_update = partition if out_of_range?(range, srt_seconds)
    elsif srt_seconds >= range.first && srt_seconds < range.last
      partition_to_update = partition
    end

    partition_to_update
  end

  def out_of_range?(range, srt_seconds)
    ((range == @min_range) && (srt_seconds < range)) || ((range == @max_range) && (srt_seconds >= range))
  end

  # example ranges = [1, [1,3], [3,5], [5,10], [10,20], 20]
  # @return [Array<Hash>]
  def init_samples_breakup
    ranges = []
    self.client_stat
        .execution_cycle
        .project
        .samples_breakup_interval # example "1,3,5,10,20"
        .split(/\s*,\s*/)
        .collect(&:to_i)
        .each do |boundary|

      if ranges.empty?
        ranges.push(boundary, boundary)
      else
        last_boundary = ranges.pop
        ranges.push([last_boundary, boundary], boundary)
      end
    end
    @min_range ||= ranges.first
    @max_range ||= ranges.last
    ranges.collect { |r| { r: r, c: 0, p: nil } }
  end

  def calc_stat_duration(response_time, start_time)
    end_time = start_time + response_time
    self.min_start_time = start_time if choose_min(value: start_time, min: self.min_start_time)
    self.max_end_time = end_time if choose_max(value: end_time, max: self.max_end_time)
  end

  def calc_response_time_facts(response_time)
    self.cumulative_response_time += response_time
    self.cumulative_squared_response_time += (response_time**2)
    self.page_sample_times.push(response_time)

    self.minimum_response_time = response_time if choose_min(value: response_time, min: self.minimum_response_time)
    self.maximum_response_time = response_time if choose_max(value: response_time, max: self.maximum_response_time)
  end

  def set_defaults
    self.samples_count = 0 if self.new_record? && self.samples_count.blank?
    self.cumulative_response_time = 0
    self.cumulative_squared_response_time = 0
    self.page_sample_times = Hailstorm::Support::Quantile.new
    self.cumulative_bytes = 0
    self.errors_count = 0
  end

  def calculate_aggregates
    self.average_response_time = (self.cumulative_response_time.to_f / self.samples_count)
    compute_quantiles
    compute_throughput
    self.percentage_errors = (self.errors_count.to_f / self.samples_count) * 100
    self.standard_deviation = ((self.cumulative_squared_response_time.to_f / self.samples_count) -
        (self.average_response_time**2))**0.5
    compute_samples_breakup
  end

  def compute_samples_breakup
    self.samples_breakup.each do |partition|
      partition[:p] = format('%2.2f', (partition[:c].to_f * 100) / self.samples_count)
    end
    self.samples_breakup_json = self.samples_breakup.to_json
  end

  def compute_throughput
    self.size_throughput = (self.cumulative_bytes.to_f * 1000) / ((self.max_end_time - self.min_start_time) * 1024)
    # KB/sec

    self.response_throughput = (self.samples_count.to_f * 1000) / (self.max_end_time - self.min_start_time)
  end

  def compute_quantiles
    logger.debug { "Calculating median_response_time for #{self.page_label}..." }
    self.median_response_time = self.page_sample_times.quantile(50)
    logger.debug { "Calculating ninety_percentile_response_time for #{self.page_label}..." }
    self.ninety_percentile_response_time = self.page_sample_times.quantile(90)
    logger.debug { '... finished calculating quantiles' }
  end

  def choose_min(value:, min:)
    min.nil? || value < min
  end

  def choose_max(value:, max:)
    max.nil? || value > max
  end
end
