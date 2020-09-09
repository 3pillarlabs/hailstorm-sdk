# frozen_string_literal: true

# Command line helpers
module CmdLineHelper
  def capture_cmd_output
    captured_stream = Tempfile.new(:stdout.to_s)
    origin_stream = $stdout.dup
    $stdout.reopen(captured_stream)

    yield

    $stdout.rewind
    captured_stream.read
  ensure
    captured_stream.close
    captured_stream.unlink
    $stdout.reopen(origin_stream)
  end
end

World(CmdLineHelper)
