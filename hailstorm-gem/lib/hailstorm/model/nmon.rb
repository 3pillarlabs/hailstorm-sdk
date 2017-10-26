require 'hailstorm/model'
require 'hailstorm/model/target_host'
require 'hailstorm/support/ssh'

# Nmon monitor for target hosts
# @author Sayantam Dey
class Hailstorm::Model::Nmon < Hailstorm::Model::TargetHost
  validates :executable_path, :ssh_identity, :user_name, presence: true, if: proc { |r| r.active? }

  validates :sampling_interval, numericality: { greater_than: 0 }, if: proc { |r| r.active? }

  validate :identity_file_exists, if: proc { |r| r.active? }

  before_validation :set_defaults

  # Check nmon is installed at configured location and terminate if already
  # executing.
  # (see Hailstorm::Behavior::Moniterable#setup)
  def setup
    logger.debug { "#{self.class}##{__method__}" }
    Hailstorm::Support::SSH.start(*ssh_connection_spec) do |ssh|
      if ssh.file_exists?(self.executable_path)
        unless self.executable_pid.blank?
          ssh.terminate_process(self.executable_pid)
          self.executable_pid = nil
        end
      else
        raise(Hailstorm::Exception, "nmon not found at #{target.executable_path} on #{target.host_name}.")
      end
    end # ssh
  end

  # start nmon on target_host
  # (see Hailstorm::Behavior::Moniterable#start_monitoring)
  def start_monitoring
    logger.debug { "#{self.class}##{__method__}" }
    if self.executable_pid.nil?
      Hailstorm::Support::SSH.start(*ssh_connection_spec) do |ssh|
        unless ssh.directory_exists?(nmon_output_path)
          ssh.make_directory(nmon_output_path)
        end

        command = format('%s -F %s -s %d -t -p', self.executable_path,
                         nmon_outfile_path, self.sampling_interval)
        nmon_pid = ssh.exec!(command)
        nmon_pid.chomp!
        self.executable_pid = nmon_pid
      end # ssh
    end
  end

  # (see Hailstorm::Behavior::Moniterable#stop_monitoring)
  def stop_monitoring
    logger.debug { "#{self.class}##{__method__}" }
    unless self.executable_pid.nil?
      Hailstorm::Support::SSH.start(*ssh_connection_spec) do |ssh|
        if ssh.process_running?(self.executable_pid)
          ssh.exec!("kill -USR2 #{self.executable_pid}")
          sleep(5)
          if ssh.process_running?(self.executable_pid)
            raise(Hailstorm::Exception, "nmon could not be stopped on #{self.host_name} (#{self.role_name})")
          else
            self.executable_pid = nil
          end
        end
      end # ssh
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

      ssh.exec!("rm -rf #{nmon_output_path}")
    end # ssh
  end

  # (see Hailstorm::Behavior::Moniterable#download_remote_log)
  def download_remote_log(local_log_path)
    logger.debug { "#{self.class}##{__method__}" }

    local_log_file_path = File.join(local_log_path, nmon_outfile_name)
    Hailstorm::Support::SSH.start(*ssh_connection_spec) do |ssh|
      ssh.download(nmon_outfile_path, local_log_file_path)
    end

    [nmon_outfile_name]
  end

  # (see Hailstorm::Behavior::Moniterable#analyze_log_files)
  # Note that every time this method is called, the average and
  # trends statistics are re-computed.
  # @param [Array] log_file_paths (String)
  def analyze_log_files(log_file_paths, start_time, end_time)
    logger.debug { "#{self.class}##{__method__}" }

    reset_counters

    # compute the count of samples collected and only collect same number of samples
    # from log files (adding 1 for millisecond correction)
    samples_count = ((end_time - start_time) / self.sampling_interval).to_i + 1
    cpu_samples_count = 0
    memory_samples_count = 0

    # nmon will output a single log file per invocation
    log_file_path = log_file_paths.first
    cpu_rexp = Regexp.compile('^CPU_ALL')
    mem_rexp = Regexp.compile('^MEM')
    comma_rexp = Regexp.compile('\s*,\s*')

    cpu_trend_file = File.open(cpu_trend_file_path, 'w')
    # User,Sys,Total

    memory_trend_file = File.open(memory_trend_file_path, 'w')
    swap_trend_file = File.open(swap_trend_file_path, 'w')

    File.open(log_file_path, 'r') do |file|
      file.each_line do |line|
        line.chomp!

        if cpu_rexp.match(line) && (cpu_samples_count < samples_count)
          # this is the CPU_ALL line
          # 0       1                 2       3
          # CPU_ALL,CPU Total ubuntu,<User%>,<Sys%>,Wait%,Idle%,Busy,CPUs
          cpu_tokens = line.split(comma_rexp).slice(2, 2).collect(&:to_f)
          cpu_tokens << average_cpu_usage(cpu_tokens.inject(0.0) { |s, e| s += e })

          cpu_trend_file.puts(cpu_tokens.join(','))
          cpu_samples_count += 1
        end

        if mem_rexp.match(line) && (memory_samples_count < samples_count)
          # this is the MEM line
          mem_tokens = line.split(comma_rexp)

          mem_total = mem_tokens[2].to_f
          swap_total = mem_tokens[5].to_f
          mem_free = mem_tokens[6].to_f
          swap_free = mem_tokens[9].to_f

          memory_used = mem_total - mem_free
          memory_trend_file.puts average_memory_usage(memory_used)

          swap_used = swap_total - swap_free
          swap_trend_file.puts average_swap_usage(swap_used)

          memory_samples_count += 1
        end

        break if (cpu_samples_count >= samples_count) && (memory_samples_count >= samples_count)
      end
    end
  ensure
    cpu_trend_file.close unless cpu_trend_file.nil?
    memory_trend_file.close unless memory_trend_file.nil?
    swap_trend_file.close unless swap_trend_file.nil?
  end

  # (see Hailstorm::Behavior::Moniterable#average_cpu_usage)
  # Since Nmon uses a log file approach, the start_time and end_time options
  # are ignored. The *args used are for internal use only, to get the computed
  # value, call this method without any arguments.
  def average_cpu_usage(*args)
    if (args.length == 1) && args.first.is_a?(Float)
      @cumulative_cpu_usage ||= 0.0
      @cpu_samples_count ||= 0
      @cumulative_cpu_usage += args.first
      @cpu_samples_count += 1

      args.first
    else
      @average_cpu_usage ||= (@cumulative_cpu_usage.to_f / @cpu_samples_count)
    end
  end

  # (see #average_cpu_usage)
  def average_memory_usage(*args)
    if (args.length == 1) && args.first.is_a?(Float)
      @cumulative_memory_usage ||= 0.0
      @memory_samples_count ||= 0
      @cumulative_memory_usage += args.first
      @memory_samples_count += 1

      args.first
    else
      @average_memory_usage ||= (@cumulative_memory_usage.to_f / @memory_samples_count)
    end
  end

  # (see #average_cpu_usage)
  def average_swap_usage(*args)
    if (args.length == 1) && args.first.is_a?(Float)
      @cumulative_swap_usage ||= 0.0
      @swap_samples_count ||= 0
      @cumulative_swap_usage += args.first
      @swap_samples_count += 1

      args.first
    else
      @average_swap_usage ||= (@cumulative_swap_usage.to_f / @swap_samples_count)
    end
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
        next unless sample > 0.0
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

  # Full path to nmon log file on target_host
  def nmon_outfile_path
    @nmon_outfile_path ||= [nmon_output_path, nmon_outfile_name].join('/')
  end

  def nmon_outfile_name
    @nmon_outfile_name ||= [log_file_name, 'nmon'].join('.')
  end

  # Path to nmon output files on target_host
  def nmon_output_path
    '/tmp/nmon_output'
  end

  def identity_file_exists
    unless File.exist?(identity_file_path)
      errors.add(:ssh_identity, "not found at #{identity_file_path}")
    end
  end

  def identity_file_path
    File.join(Hailstorm.root, Hailstorm.config_dir,
              self.ssh_identity.gsub(/\.pem$/, '').concat('.pem'))
  end

  # Array of options to connect to target_host with SSH. Pass to SSH#start
  # as *ssh_connection_spec
  def ssh_connection_spec
    [self.host_name, self.user_name, { keys: identity_file_path }]
  end

  # Set default values for attributes if they are not set
  def set_defaults
    self.executable_path ||= '/usr/bin/nmon'
    self.sampling_interval ||= 10
  end

  def cpu_trend_file_path
    File.join(Hailstorm.tmp_path, "cpu_trend-#{current_execution_context}-#{id}.log")
  end

  def memory_trend_file_path
    File.join(Hailstorm.tmp_path, "memory_trend-#{current_execution_context}-#{id}.log")
  end

  def swap_trend_file_path
    File.join(Hailstorm.tmp_path, "swap_trend-#{current_execution_context}-#{id}.log")
  end

  def reset_counters
    @cumulative_cpu_usage = 0
    @cumulative_memory_usage = 0
    @cumulative_swap_usage = 0
    @cpu_samples_count = 0
    @memory_samples_count = 0
    @swap_samples_count = 0
  end
end
