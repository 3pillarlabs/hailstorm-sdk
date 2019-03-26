require 'zlib'
require 'hailstorm/model/execution_cycle'
require 'hailstorm/model/target_host'

# Statistics for target monitoring
# @author Sayantam Dey
class Hailstorm::Model::TargetStat < ActiveRecord::Base

  DEFAULT_SELECT_COLUMNS = %i[id execution_cycle_id target_host_id
                              average_cpu_usage average_memory_usage average_swap_usage].freeze

  belongs_to :execution_cycle

  belongs_to :target_host

  after_create :write_blobs, if: ->(r) { r.target_host.active? }

  default_scope { select(DEFAULT_SELECT_COLUMNS.collect { |e| "target_stats.#{e}" }.join(',')) }

  def self.create_target_stat(execution_cycle, target_host)
    logger.debug { "#{self}.#{__method__}" }
    target_stat = target_host.target_stats.build(execution_cycle_id: execution_cycle.id)
    target_stat.average_cpu_usage,
    target_stat.average_memory_usage,
    target_stat.average_swap_usage = target_host.calculate_average_stats(execution_cycle.started_at,
                                                                         execution_cycle.stopped_at)
    target_stat.save!
    target_stat
  end

  # @return [String] path to outfile file
  def utilization_graph(width: 640, height: 600, builder: nil)
    output_path = File.join(Hailstorm.root, Hailstorm.reports_dir, "target_stat_graph_#{self.id}")
    grapher = GraphBuilderFactory.utilization_graph(output_path,
                                                    self.target_host.sampling_interval,
                                                    other_builder: builder)
    grapher.startBuilder

    cpu_usage_file_path = dump_usage_data(:cpu, :cpu_usage_trend)
    self.target_host.each_cpu_usage_sample(cpu_usage_file_path) do |sample|
      grapher.addCpuUsageSample(sample.to_f)
    end
    memory_usage_file_path = dump_usage_data(:memory, :memory_usage_trend)
    self.target_host.each_memory_usage_sample(memory_usage_file_path) do |sample|
      grapher.addMemoryUsageSample(sample.to_f)
    end
    swap_usage_file_path = dump_usage_data(:swap, :swap_usage_trend)
    self.target_host.each_swap_usage_sample(swap_usage_file_path) do |sample|
      grapher.addSwapUsageSample(sample.to_f)
    end

    grapher.finish(width, height) # returns path to graph file
  end

  private

  # Fetches data for blob columns and fills them
  def write_blobs
    logger.debug { "#{self.class}.#{__method__}" }
    self.target_host.cpu_usage_trend do |io|
      write_metric_blob(io, metric: :cpu, attribute_name: :cpu_usage_trend)
    end

    self.target_host.memory_usage_trend do |io|
      write_metric_blob(io, metric: :memory, attribute_name: :memory_usage_trend)
    end

    self.target_host.swap_usage_trend do |io|
      write_metric_blob(io, metric: :swap, attribute_name: :swap_usage_trend)
    end
  end

  def write_metric_blob(io, metric:, attribute_name:)
    logger.debug { "#{self.class}.#{__method__}" }
    path = blob_file_path(metric)
    File.open(path, 'wb') do |out|
      gz = Zlib::GzipWriter.new(out)
      gz.write(io.read(1024)) until io.eof?
      gz.close
    end

    self.update_attribute(attribute_name, IO.binread(path))
    File.unlink(path)
  end

  def blob_file_path(metric, inflated = false)
    File.join(Hailstorm.tmp_path,
              "#{metric}_trend-#{self.execution_cycle.id}-#{self.target_host.id}.log#{inflated ? '' : '.gz'}")
  end


  # Dumps the uncompressed metric blobs to a temporary location
  # @param [Symbol] metric one of :memory, :cpu. :swap
  # @param [Symbol] db_column_name
  # @return [String] path to file
  def dump_usage_data(metric, db_column_name)
    file_path = blob_file_path(metric, true)
    File.open(file_path, 'w') do |outfile|
      StringIO.open(self.class
                    .unscoped
                    .where(id: self.id)
                    .select("id, #{db_column_name}")
                    .first
                    .send(db_column_name.to_sym)) do |strio|

        gz = Zlib::GzipReader.new(strio)
        outfile.write(gz.read(1024)) until gz.eof?
        gz.close
      end
    end

    file_path
  end

  # Factory for building graph builders
  class GraphBuilderFactory

    def self.utilization_graph(output_path, sampling_interval, other_builder: nil)
      if other_builder.nil?
        grapher_klass = com.brickred.tsg.hailstorm.ResourceUtilizationGraph
        grapher_klass.new(output_path, sampling_interval)
      else
        other_builder.output_path = output_path
        other_builder.sampling_interval = sampling_interval
        other_builder
      end
    end
  end
end
