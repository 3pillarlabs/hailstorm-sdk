
require "hailstorm/model"
require "hailstorm/model/client_stat"
require 'hailstorm/support/quantile'

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
    self.cumulative_response_time += sample_response_time
    self.cumulative_squared_response_time += (sample_response_time ** 2)
    self.page_sample_times.push(sample_response_time)

    if self.minimum_response_time.nil? or sample_response_time < self.minimum_response_time
      self.minimum_response_time = sample_response_time
    end

    if self.maximum_response_time.nil? or sample_response_time > self.maximum_response_time
      self.maximum_response_time = sample_response_time
    end

    sample_start_time = sample['ts'].to_i
    sample_end_time = sample_start_time + sample_response_time
    if self.min_start_time.nil? or sample_start_time < self.min_start_time
      self.min_start_time = sample_start_time
    end
    if self.max_end_time.nil? or sample_end_time > self.max_end_time
      self.max_end_time = sample_end_time
    end
    self.cumulative_bytes += sample['by'].to_i

    self.samples_breakup(sample_response_time)

    sample_success = eval(sample['s']) rescue false # 's' is either "true" or "false"
    self.errors_count += 1 unless sample_success
  end

  def samples_breakup(sample_response_time = nil)

    if @samples_breakup.nil?
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
          last_boundary = ranges.pop()
          ranges.push([last_boundary, boundary], boundary)
        end
      end # example ranges = [1, [1,3], [3,5], [5,10], [10,20], 20]
      @min_range ||= ranges.first
      @max_range ||= ranges.last
      @samples_breakup = ranges.collect {|r| {:r => r, :c => 0, :p => nil} }
      # @samples_breakup would be an Array of Hash
    end

    unless sample_response_time.nil?
      srt_seconds = (sample_response_time.to_f / 1000)
      partition_to_update = nil
      @samples_breakup.each do |partition|
        range = partition[:r]
        unless range.is_a?(Array)
          if (range == @min_range and srt_seconds < range) or
              (range == @max_range and srt_seconds >= range)

            partition_to_update = partition
            break
          end
        else
          if srt_seconds >= range.first and srt_seconds < range.last
            partition_to_update = partition
            break
          end
        end
      end

      partition_to_update[:c] += 1
    end

    @samples_breakup
  end

  def stat_item()
    OpenStruct.new(self.attributes()
                       .symbolize_keys()
                       .except(:id, :client_stat_id, :samples_breakup_json))
  end

  private

  def set_defaults()

    self.samples_count = 0 if self.new_record?
    self.cumulative_response_time = 0
    self.cumulative_squared_response_time = 0
    self.page_sample_times = Hailstorm::Support::Quantile.new()
    self.cumulative_bytes = 0
    self.errors_count = 0
  end

  def calculate_aggregates()

    self.average_response_time = (self.cumulative_response_time.to_f / self.samples_count)

    logger.debug { "Calculating median_response_time for #{self.page_label}..." }
    self.median_response_time = self.page_sample_times.quantile(50)
    logger.debug { "Calculating ninety_percentile_response_time for #{self.page_label}..." }
    self.ninety_percentile_response_time = self.page_sample_times.quantile(90)
    logger.debug { "... finished calculating quantiles" }

    self.size_throughput = (self.cumulative_bytes.to_f * 1000) /
        ((self.max_end_time - self.min_start_time) * 1024)
    # KB/sec

    self.response_throughput = (self.samples_count.to_f * 1000) /
        (self.max_end_time - self.min_start_time)

    self.percentage_errors = (self.errors_count.to_f / self.samples_count) * 100

    self.standard_deviation = ((self.cumulative_squared_response_time.to_f / self.samples_count) -
        (self.average_response_time ** 2)) ** 0.5

    # calculate percentage for @samples_breakup
    self.samples_breakup.each do |partition|
      partition[:p] = sprintf('%2.2f', (partition[:c].to_f * 100) / self.samples_count)
    end
    self.samples_breakup_json = self.samples_breakup.to_json()
  end

  # Calculates the array index for percentile
  # @param [Fixnum] percentile example 50, 90
  # @return [Fixnum]
  def percentile_index(percentile)

    index = (self.samples_count * percentile.to_f / 100).to_i
    index == 0 ? index : index - 1
  end

end