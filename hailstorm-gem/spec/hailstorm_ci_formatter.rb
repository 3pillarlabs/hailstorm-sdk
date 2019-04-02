require 'java'
require 'stringio'
require 'rspec/core/formatters/base_text_formatter'

# Formatter for CI. Captures stdout and stderr during an example run, and dumps them for failed examples only.
# Progress is shown as per progress formatter.
class HailstormCiFormatter < RSpec::Core::Formatters::BaseTextFormatter

  attr_accessor :stdout_str_io, :stderr_str_io, :pw_out, :pw_err, :java_stdout, :java_stderr

  def start(example_count)
    super(example_count)

    capture_io
  end

  def example_started(example)
    super(example)

    capture_io
  end

  def example_passed(example)
    super(example)

    restore_io

    output.print success_color('.')
  end

  def example_pending(example)
    super(example)

    restore_io

    output.print pending_color('*')
  end

  def example_failed(example)
    super(example)

    restore_io

    captured_io_value = [
      stdout_str_io.string,
      read_out_stream,
      stderr_str_io.string,
      read_err_stream
    ].select { |s| s.to_s.length > 0 }.join("\n")

    class << example
      attr_reader :captured_io
    end

    example.instance_variable_set('@captured_io', captured_io_value)

    output.print failure_color('F')
  end

  def dump_failures
    return if failed_examples.empty?

    output.puts
    output.puts "Failures:"
    failed_examples.each_with_index do |example, index|
      output.puts
      pending_fixed?(example) ? dump_pending_fixed(example, index) : dump_failure(example, index)
      dump_backtrace(example)
      output.puts example.captured_io
    end
  end

  private

  def capture_stdout
    self.stdout_str_io = StringIO.new
    $stdout = self.stdout_str_io
    self.java_stdout = java.lang.System.out
    self.pw_out.close unless self.pw_out.nil?
    self.pw_out = out_stream
    java.lang.System.setOut(self.pw_out)
  end

  def capture_stderr
    self.stderr_str_io = StringIO.new
    $stderr = self.stderr_str_io
    self.java_stderr = java.lang.System.err
    self.pw_err.close unless self.pw_err.nil?
    self.pw_err = err_stream
    java.lang.System.setErr(self.pw_err)
  end

  def capture_io
    capture_stdout
    capture_stderr
  end

  def restore_stdout
    $stdout = STDOUT
    java.lang.System.setOut(self.java_stdout)
    self.pw_out.close
  end

  def restore_stderr
    $stderr = STDERR
    java.lang.System.setErr(self.java_stderr)
    self.pw_err.close
  end

  def restore_io
    restore_stdout
    restore_stderr
  end

  def out_stream
    @byte_out_stream = java.io.ByteArrayOutputStream.new
    java.io.PrintStream.new(@byte_out_stream)
  end

  def err_stream
    @byte_err_stream = java.io.ByteArrayOutputStream.new
    java.io.PrintStream.new(@byte_err_stream)
  end

  def read_out_stream
    @byte_out_stream.to_string('utf-8')
  end

  def read_err_stream
    @byte_err_stream.to_string('utf-8')
  end
end
