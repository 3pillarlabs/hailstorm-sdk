require 'hailstorm/model'
require 'hailstorm/behavior/sshable'
require 'hailstorm/model/target_host'
require 'hailstorm/support/ssh'

# Nmon monitor for target hosts
# @author Sayantam Dey
class Hailstorm::Model::Nmon < Hailstorm::Model::TargetHost

  include Hailstorm::Behavior::SSHable

  # Path to nmon output files on target_host
  NMON_OUTPUT_PATH = '/tmp/nmon_output'.freeze

  validates :executable_path, :ssh_identity, :user_name, presence: true, if: proc { |r| r.active? }

  validates :sampling_interval, numericality: { greater_than: 0 }, if: proc { |r| r.active? }

  validate :identity_file_exists, if: proc { |r| r.active? }

  before_validation :set_defaults

  # Operations of a monitor
  module MoniterableOps
    # Check nmon is installed at configured location and terminate if already
    # executing.
    # (see Hailstorm::Behavior::Moniterable#setup)
    def setup
      logger.debug { "#{self.class}##{__method__}" }
      Hailstorm::Support::SSH.start(*ssh_connection_spec) do |ssh|
        unless ssh.file_exists?(self.executable_path)
          raise(Hailstorm::Exception, "nmon not found at #{self.executable_path} on #{self.host_name}.")
        end

        break if self.executable_pid.blank?
        ssh.terminate_process(self.executable_pid)
        self.executable_pid = nil
      end
    end

    # start nmon on target_host
    # (see Hailstorm::Behavior::Moniterable#start_monitoring)
    def start_monitoring
      logger.debug { "#{self.class}##{__method__}" }
      return unless self.executable_pid.nil?
      Hailstorm::Support::SSH.start(*ssh_connection_spec) do |ssh|
        ssh.make_directory(NMON_OUTPUT_PATH) unless ssh.directory_exists?(NMON_OUTPUT_PATH)

        command = format('%<bin_path>s -F %<out_file>s -s %<interval>d -t -p',
                         bin_path: self.executable_path,
                         out_file: nmon_outfile_path,
                         interval: self.sampling_interval)
        nmon_pid = ssh.exec!(command)
        nmon_pid.chomp!
        self.executable_pid = nmon_pid
      end
    end

    # (see Hailstorm::Behavior::Moniterable#stop_monitoring)
    def stop_monitoring(doze_time = 5)
      logger.debug { "#{self.class}##{__method__}" }
      return if self.executable_pid.nil?
      Hailstorm::Support::SSH.start(*ssh_connection_spec) do |ssh|
        break unless ssh.process_running?(self.executable_pid)
        ssh.exec!("kill -USR2 #{self.executable_pid}")
        sleep(doze_time)
        if ssh.process_running?(self.executable_pid)
          raise(Hailstorm::Exception, "nmon could not be stopped on #{self.host_name} (#{self.role_name})")
        end

        self.executable_pid = nil
      end
    end

    # (see Hailstorm::Behavior::Moniterable#cleanup)
    def cleanup
      logger.debug { "#{self.class}##{__method__}" }
      Hailstorm::Support::SSH.start(*ssh_connection_spec) do |ssh|
        unless self.executable_pid.nil?
          ssh.terminate_process(executable_pid)
          self.executable_pid = nil
        end

        ssh.exec!("rm -rf #{NMON_OUTPUT_PATH}")
      end
    end
  end

  # Reporting functions for a monitor
  module MoniterableReporter

    # @see Hailstorm::Behavior::Moniterable#populate_averages
    def calculate_average_stats(started_at, stopped_at)
      logger.debug { "#{self.class}.#{__method__}" }
      local_log_file_path = download_remote_log
      averages = []
      File.open(local_log_file_path, 'r') do |log_io|
        averages.push(*analyze_log_file(log_io, started_at, stopped_at))
      end
      File.unlink(local_log_file_path) if Hailstorm.is_production?
      averages
    end

    # Calculator for averages
    class Calculator
      CPU_REXP = Regexp.compile('^CPU_ALL')
      MEM_REXP = Regexp.compile('^MEM')
      COMMA_REXP = Regexp.compile('\s*,\s*')

      attr_reader :samples_stream, :samples_count

      # @param [IO] new_sample_stream
      # @param [Integer] new_samples_count
      def initialize(new_sample_stream, new_samples_count)
        @samples_stream = new_sample_stream
        @samples_count = new_samples_count
        @cumulative_cpu_usage = 0.0
        @cumulative_memory_usage = 0.0
        @cumulative_swap_usage = 0.0
        @cpu_samples_count = 0
        @memory_samples_count = 0
      end

      def analyze_each_sample
        self.samples_stream.each_line do |line|
          line.chomp!
          cpu_sample = match_cpu_sample(line)
          mem_sample, swap_sample = match_mem_sample(line)
          yield(cpu_sample, mem_sample, swap_sample)
          break if @cpu_samples_count >= self.samples_count && @memory_samples_count >= samples_count
        end
      end

      def average_cpu_usage
        @cumulative_cpu_usage / @cpu_samples_count
      end

      def average_mem_usage
        @cumulative_memory_usage / @memory_samples_count
      end

      def average_swap_usage
        @cumulative_swap_usage / @memory_samples_count
      end

      private

      # @param [String] line
      def match_cpu_sample(line)
        return nil unless CPU_REXP.match(line) && @cpu_samples_count < self.samples_count
        # this is the CPU_ALL line
        # 0       1                 2       3
        # CPU_ALL,CPU Total ubuntu,<User%>,<Sys%>,Wait%,Idle%,Busy,CPUs
        tokens = line.split(COMMA_REXP)
        return nil if tokens[2] == 'User%' # skip header
        cpu_tokens = tokens.slice(2, 2).collect(&:to_f)
        total_cpu = cpu_tokens.inject(0.0) { |s, e| s + e }
        @cumulative_cpu_usage += total_cpu
        cpu_tokens << total_cpu
        @cpu_samples_count += 1
        cpu_tokens.join(',')
      end

      def match_mem_sample(line)
        return nil unless MEM_REXP.match(line) && @memory_samples_count < self.samples_count
        # this is the MEM line
        # 0   1                  2        3         4        5         6       7        8       9
        # MEM,Memory MB vmtuxbox,memtotal,hightotal,lowtotal,swaptotal,memfree,highfree,lowfree,swapfree,...
        mem_tokens = line.split(COMMA_REXP)
        return nil if mem_tokens[2] == 'memtotal' # skip header
        mem_total = mem_tokens[2].to_f
        swap_total = mem_tokens[5].to_f
        mem_free = mem_tokens[6].to_f
        swap_free = mem_tokens[9].to_f

        memory_used = mem_total - mem_free
        @cumulative_memory_usage += memory_used

        swap_used = swap_total - swap_free
        @cumulative_swap_usage += swap_used

        @memory_samples_count += 1
        [memory_used, swap_used]
      end
    end

    # Note that every time this method is called, the average and
    # trends statistics are re-computed.
    # @param [IO] log_io
    def analyze_log_file(log_io, start_time, end_time)
      logger.debug { "#{self.class}##{__method__}" }
      # compute the count of samples collected and only collect same number of samples
      # from log files (adding 1 for millisecond correction)
      samples_count = ((end_time - start_time) / self.sampling_interval).to_i + 1
      calculator = Calculator.new(log_io, samples_count)

      with_output do |observer|
        calculator.analyze_each_sample do |cpu_sample, mem_sample, swap_sample|
          observer.next_cpu_sample(cpu_sample)
          observer.next_mem_sample(mem_sample)
          observer.next_swap_sample(swap_sample)
        end
      end

      [calculator.average_cpu_usage, calculator.average_mem_usage, calculator.average_swap_usage]
    end

    # (see Hailstorm::Behavior::Moniterable#cpu_usage_trend)
    def cpu_usage_trend
      if block_given?
        File.open(cpu_trend_file_path, 'r') do |io|
          yield(io)
        end
        File.unlink(cpu_trend_file_path)
      else
        File.open(cpu_trend_file_path, 'r')
      end
    end

    # (see #cpu_usage_trend)
    def memory_usage_trend
      if block_given?
        File.open(memory_trend_file_path, 'r') do |io|
          yield(io)
        end
        File.unlink(memory_trend_file_path)
      else
        File.open(memory_trend_file_path, 'r')
      end
    end

    # (see #cpu_usage_trend)
    def swap_usage_trend
      if block_given?
        File.open(swap_trend_file_path, 'r') do |io|
          yield(io)
        end
        File.unlink(swap_trend_file_path)
      else
        File.open(swap_trend_file_path, 'r')
      end
    end

    # (see Hailstorm::Behavior::Moniterable#each_cpu_usage_sample)
    def each_cpu_usage_sample(cpu_usage_file_path)
      File.open(cpu_usage_file_path, 'r') do |inf|
        inf.each_line do |line|
          line.chomp!
          sample = line.split(',').last.to_f
          yield sample
        end
      end

      File.unlink(cpu_usage_file_path)
    end

    # (see Hailstorm::Behavior::Moniterable#each_memory_usage_sample)
    def each_memory_usage_sample(memory_usage_file_path)
      File.open(memory_usage_file_path, 'r') do |inf|
        inf.each_line do |line|
          line.chomp!
          sample = line.to_f
          yield sample
        end
      end

      File.unlink(memory_usage_file_path)
    end

    # (see Hailstorm::Behavior::Moniterable#each_swap_usage_sample)
    def each_swap_usage_sample(swap_usage_file_path)
      File.open(swap_usage_file_path, 'r') do |inf|
        inf.each_line do |line|
          line.chomp!
          sample = line.to_f
          yield sample
        end
      end

      File.unlink(swap_usage_file_path)
    end

    private

    def cpu_trend_file_path
      File.join(Hailstorm.tmp_path, "cpu_trend-#{current_execution_context}-#{id}.log")
    end

    def memory_trend_file_path
      File.join(Hailstorm.tmp_path, "memory_trend-#{current_execution_context}-#{id}.log")
    end

    def swap_trend_file_path
      File.join(Hailstorm.tmp_path, "swap_trend-#{current_execution_context}-#{id}.log")
    end

    def download_remote_log
      logger.debug { "#{self.class}##{__method__}" }
      local_log_file_path = File.join(Hailstorm.root, Hailstorm.log_dir, nmon_outfile_name)
      Hailstorm::Support::SSH.start(*ssh_connection_spec) do |ssh|
        ssh.download(nmon_outfile_path, local_log_file_path)
      end
      local_log_file_path
    end

    def with_output
      subject = Object.new
      class << subject
        attr_accessor :cpu_io, :mem_io, :swap_io

        def next_cpu_sample(sample)
          # User,Sys,Total
          cpu_io.puts(sample) if sample
        end

        def next_mem_sample(sample)
          mem_io.puts(sample) if sample
        end

        def next_swap_sample(sample)
          swap_io.puts(sample) if sample
        end
      end

      subject.cpu_io = File.open(cpu_trend_file_path, 'w')
      subject.mem_io = File.open(memory_trend_file_path, 'w')
      subject.swap_io = File.open(swap_trend_file_path, 'w')

      yield subject
    ensure
      subject.cpu_io.close
      subject.mem_io.close
      subject.swap_io.close
    end
  end

  include MoniterableOps
  include MoniterableReporter

  private

  # Full path to nmon log file on target_host
  def nmon_outfile_path
    @nmon_outfile_path ||= [NMON_OUTPUT_PATH, nmon_outfile_name].join('/')
  end

  def nmon_outfile_name
    @nmon_outfile_name ||= [log_file_name, 'nmon'].join('.')
  end

  def identity_file_exists
    errors.add(:ssh_identity, "not found at #{identity_file_path}") unless identity_file_ok?
  end

  def identity_file_name
    @identity_file_name ||= self.ssh_identity.gsub(/\.pem$/, '').concat('.pem')
  end

  # Set default values for attributes if they are not set
  def set_defaults
    self.executable_path ||= '/usr/bin/nmon'
    self.sampling_interval ||= 10
  end
end
