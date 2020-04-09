require 'hailstorm/behavior'
require 'hailstorm/behavior/loggable'

# Mixin for all monitors, provides implementation for some common tasks
# and defines "abstract" methods for the delegates.
# @author Sayantam Dey
module Hailstorm::Behavior::Moniterable

  include Hailstorm::Behavior::Loggable

  # :nocov:

  # An "abstract" method definition. Implementation should start resource
  # monitoring on the target host.
  # @abstract
  def start_monitoring
    raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
  end

  # An "abstract" method definition. Implementation should stop resource
  # monitoring on the target host.
  # @abstract
  def stop_monitoring
    raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
  end

  # An "abstract" method definition. Implementation should yield or return an
  # IO instance, which will be read for trend information. If a block is provided,
  # the implementation should close the IO connection gracefully. These methods
  # will always be called after the averages methods are called, so the same
  # execution context will apply.
  # @abstract
  def cpu_usage_trend(&_block)
    raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
  end

  # (see #cpu_usage_trend)
  def memory_usage_trend(&_block)
    raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
  end

  # (see #cpu_usage_trend)
  def swap_usage_trend(&_block)
    raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
  end

  # Implement this method to parse the CPU usage file and return/yield each sample
  # (total CPU% used). The file format and data would be same as originally captured by
  # the implementation.
  # @param [String] _cpu_usage_file_path path to usage file
  # @abstract
  def each_cpu_usage_sample(_cpu_usage_file_path, &_block)
    raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
  end

  # Same as #each_cpu_usage_sample, but this is for memory usage.
  # @param [String] _memory_usage_file_path path to usage file
  # @abstract
  def each_memory_usage_sample(_memory_usage_file_path, &_block)
    raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
  end

  # Same as #each_cpu_usage_sample, but this is for swap usage.
  # @param [String] _swap_usage_file_path path to usage file
  # @abstract
  def each_swap_usage_sample(_swap_usage_file_path, &_block)
    raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
  end

  # Calculates and sets the averages fields on _target_stat.
  # @abstract
  # @param [DateTime] _started_at the begin time for the data collection
  # @param [DateTime] _stopped_at the end time for the data collection
  # @return [Array<Float>] (cpu, memory, swap) average from started_at to stopped_at
  def calculate_average_stats(_started_at, _stopped_at)
    raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
  end

  # An empty method definition. Implementation should override to perform activities
  # necessary prior to starting the monitoring service. The implementation can
  # make changes to the state of the record, but should not persist the changes.
  def setup
    # override and do something appropriate
  end

  # An empty method definition. Implementation should override to cleanup or do
  # other housekeeping activities at the end of a test cycle/run.
  def cleanup
    # override and do something appropriate
  end

  # :nocov:
end
