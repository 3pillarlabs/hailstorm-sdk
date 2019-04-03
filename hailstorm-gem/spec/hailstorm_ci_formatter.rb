require 'java'
require 'stringio'
require 'rspec/core/formatters/base_text_formatter'

# Formatter for CI. Captures stdout and stderr during an example run, and dumps them for failed examples only.
# Progress is shown as per progress formatter.
class HailstormCiFormatter < RSpec::Core::Formatters::BaseTextFormatter

  attr_reader :io_stream

  def initialize(output)
    super(output)

    @io_stream = IoStream.new
  end

  def start(example_count)
    super(example_count)

    self.io_stream.capture_io
  end

  def example_started(example)
    super(example)

    self.io_stream.capture_io
  end

  def example_passed(example)
    super(example)

    self.io_stream.restore_io

    output.print success_color('.')
  end

  def example_pending(example)
    super(example)

    self.io_stream.restore_io

    output.print pending_color('*')
  end

  def example_failed(example)
    super(example)

    self.io_stream.restore_io

    class << example
      attr_reader :captured_io
    end

    example.instance_variable_set('@captured_io', self.io_stream.read_captured_io)

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

  # IO adapter
  class IoStream

    attr_reader :stdout_stream, :stderr_stream

    def initialize
      @stdout_stream = StdOutStream.new
      @stderr_stream = StdErrStream.new
    end

    def capture_io
      stdout_stream.capture_io
      stderr_stream.capture_io
    end

    def restore_io
      stdout_stream.restore_io
      stderr_stream.restore_io
    end

    def read_captured_io
      [stdout_stream.read_captured_io, stderr_stream.read_captured_io]
        .flatten
        .select { |s| s.to_s.length > 0 }
        .join("\n")
    end
  end

  # Capturable interface
  module IoCapturable
    def capture_io
      raise(NotImplementedError, "#{self.class.name}##{__method__}")
    end

    def restore_io
      raise(NotImplementedError, "#{self.class.name}##{__method__}")
    end

    def read_captured_io
      raise(NotImplementedError, "#{self.class.name}##{__method__}")
    end
  end

  # stdout
  class StdOutStream
    include IoCapturable

    attr_accessor :stdout_str_io, :pw_out, :java_stdout

    def capture_io
      self.stdout_str_io = StringIO.new
      $stdout = self.stdout_str_io
      self.java_stdout = java.lang.System.out
      self.pw_out.close unless self.pw_out.nil?
      self.pw_out = out_stream
      java.lang.System.setOut(self.pw_out)
    end

    def restore_io
      $stdout = STDOUT
      java.lang.System.setOut(self.java_stdout)
      self.pw_out.close
    end

    def read_captured_io
      [stdout_str_io.string, read_out_stream]
    end

    private

    def out_stream
      @out_stream = java.io.ByteArrayOutputStream.new
      java.io.PrintStream.new(@out_stream)
    end

    def read_out_stream
      @out_stream.to_string('utf-8')
    end
  end

  # stderr
  class StdErrStream
    include IoCapturable

    attr_accessor :stderr_str_io, :pw_err, :java_stderr

    def capture_io
      self.stderr_str_io = StringIO.new
      $stderr = self.stderr_str_io
      self.java_stderr = java.lang.System.err
      self.pw_err.close unless self.pw_err.nil?
      self.pw_err = err_stream
      java.lang.System.setErr(self.pw_err)
    end

    def restore_io
      $stderr = STDERR
      java.lang.System.setErr(self.java_stderr)
      self.pw_err.close
    end

    def read_captured_io
      [stderr_str_io.string, read_err_stream]
    end

    private

    def err_stream
      @err_stream = java.io.ByteArrayOutputStream.new
      java.io.PrintStream.new(@err_stream)
    end

    def read_err_stream
      @err_stream.to_string('utf-8')
    end
  end
end
