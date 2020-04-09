require 'hailstorm/support'

# Calculates average statistics from nmon output
class Hailstorm::Support::NmonCalculator
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
