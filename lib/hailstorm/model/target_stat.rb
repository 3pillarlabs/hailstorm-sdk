#
# @author Sayantam Dey

require 'zlib'
require 'hailstorm/model/execution_cycle'
require 'hailstorm/model/target_host'

class Hailstorm::Model::TargetStat < ActiveRecord::Base

  DefaultSelectColumns = [:id, :execution_cycle_id, :target_host_id,
      :average_cpu_usage, :average_memory_usage, :average_swap_usage]

  belongs_to :execution_cycle

  belongs_to :target_host

  before_create :populate_averages

  after_create :write_blobs

  default_scope select(DefaultSelectColumns.collect{|e| "target_stats.#{e}"}.join(','))

  attr_accessor :log_file_paths

  def self.create_target_stats(execution_cycle, target_host, log_file_paths)

    logger.debug { "#{self}.#{__method__}" }
    target_stat = target_host.target_stats.build(:execution_cycle_id => execution_cycle.id)
    target_stat.log_file_paths = log_file_paths
    target_stat.save!
  end

  # @return [String] path to outfile file
  def utilization_graph()

		grapher_klass = com.brickred.tsg.hailstorm.ResourceUtilizationGraph
    grapher = grapher_klass.new(utilization_graph_path,
																self.target_host.sampling_interval)

    grapher.startBuilder()

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

    grapher.finish() # returns path to graph file
  end

  def self.cpu_comparison_graph(execution_cyles)

    grapher_klass = com.brickred.tsg.hailstorm.TargetComparisonGraph
    grapher = grapher_klass.getCpuComparisionBuilder(comparison_graph_path(:cpu,
                                                                           execution_cyles))
    # repeated total_threads_count cause a collapsed graph - bug #Research-440
    domain_labels = []
    execution_cyles.each do |execution_cycle|
      domain_label = execution_cycle.total_threads_count().to_s
      if domain_labels.include?(domain_label)
        domain_label.concat("-#{execution_cycle.id}")
      end
      domain_labels.push(domain_label)
      execution_cycle.target_stats.includes(:target_host).each do |target_stat|
        grapher.addDataItem(target_stat.average_cpu_usage,
                            target_stat.target_host.host_name,
                            domain_label)
      end
    end

    grapher.build() unless domain_labels.empty?
  end

  def self.memory_comparison_graph(execution_cyles)

    grapher_klass = com.brickred.tsg.hailstorm.TargetComparisonGraph
    grapher = grapher_klass.getMemoryComparisionBuilder(comparison_graph_path(:memory,
                                                                              execution_cyles))
    # repeated total_threads_count cause a collapsed graph - bug #Research-440
    domain_labels = []
    execution_cyles.each do |execution_cycle|
      domain_label = execution_cycle.total_threads_count().to_s
      if domain_labels.include?(domain_label)
        domain_label.concat("-#{execution_cycle.id}")
      end
      domain_labels.push(domain_label)
      execution_cycle.target_stats.includes(:target_host).each do |target_stat|
        grapher.addDataItem(target_stat.average_memory_usage,
                            target_stat.target_host.host_name,
                            domain_label)
      end
    end

    grapher.build() unless domain_labels.empty?
  end

  private

  def populate_averages()

    logger.debug { "#{self.class}.#{__method__}" }
    self.target_host.calculate_average_stats(execution_cycle, log_file_paths) do |stats|
      [:average_cpu_usage, :average_memory_usage, :average_swap_usage].each do |attr|
        value = stats.send(attr)
        self.send("#{attr}=", value)
      end
    end
  end

  # Fetches data for blob columns and fills them
  def write_blobs()

    logger.debug { "#{self.class}.#{__method__}" }
    write_cpu_blob()
    write_memory_blob()
    write_swap_blob()
  end

  def write_cpu_blob()

    logger.debug { "#{self.class}.#{__method__}" }
    path = blob_file_path(:cpu)
    File.open(path, "wb") do |out|
      gz = Zlib::GzipWriter.new(out)
      self.target_host.cpu_usage_trend() do |io|
        gz.write(io.read(1024)) until io.eof?
      end
      gz.close
    end
    self.update_attribute(:cpu_usage_trend, IO.binread(path))

    File.unlink(path)
  end

  def write_memory_blob()

    logger.debug { "#{self.class}.#{__method__}" }
    path = blob_file_path(:memory)
    File.open(path, "wb") do |out|
      gz = Zlib::GzipWriter.new(out)
      self.target_host.memory_usage_trend() do |io|
        gz.write(io.read(1024)) until io.eof?
      end
      gz.close
    end
    self.update_attribute(:memory_usage_trend, IO.binread(path))

    File.unlink(path)
  end

  def write_swap_blob()

    logger.debug { "#{self.class}.#{__method__}" }
    path = blob_file_path(:swap)
    File.open(path, "wb") do |out|
      gz = Zlib::GzipWriter.new(out)
      self.target_host.swap_usage_trend() do |io|
        gz.write(io.read(1024)) until io.eof?
      end
      gz.close
    end
    self.update_attribute(:swap_usage_trend, IO.binread(path))

    File.unlink(path)
  end

  def blob_file_path(metric, inflated = false)
    File.join(Hailstorm.tmp_path,
        "#{metric}_trend-#{self.execution_cycle.id}-#{self.target_host.id}.log#{inflated ? '' : '.gz'}")
  end

  def utilization_graph_path()
    File.join(Hailstorm.root, Hailstorm.reports_dir, "target_stat_graph_#{self.id}")
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
                    .where(:id => self.id)
                    .select("id, #{db_column_name}")
                    .first
                    .send(db_column_name.to_sym)) do |strio|

        gz = Zlib::GzipReader.new(strio)
        outfile.write(gz.read(1024)) until gz.eof?
        gz.close()
      end
    end

    return file_path
  end

  def self.comparison_graph_path(metric, execution_cycles)

    start_id = execution_cycles.first.id
    end_id = execution_cycles.last.id
    File.join(Hailstorm.root, Hailstorm.reports_dir,
              "#{metric}_comparison_graph_#{start_id}-#{end_id}")
  end

end
