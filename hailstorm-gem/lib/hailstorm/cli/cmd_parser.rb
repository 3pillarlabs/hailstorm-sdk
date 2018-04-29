require 'optparse'
require 'hailstorm/cli'

# Command line parser for CLI command execution mode
#   parser = Hailstorm::Initializer.CmdParser.new
#   parser.set_default_handlers
#   # parse! block is called only if options are parsed successfully.
#   parser.parse!(ARGV) { |options| puts "Do something useful with #{options}" }
#
# Have your own handler for parsing errors:
#   parser.on_parse_error { |error, opt_parser| [error.reason, opt_parser] }
#
# Have your own handler for help:
#   parser.on_help { |opt_parser| opt_parser }
class Hailstorm::Cli::CmdParser

  attr_reader :options

  def initialize
    @options = {}
    @parse_error_handler = nil
    @help_handler = nil
  end

  # Define your handler to be called in case of parser error. The handler is called with
  # (error: OptionParser::ParseError, option_parser: OptionParser).
  def on_parse_error(&block)
    @parse_error_handler = block
  end

  # Define your handler to be called in case the help option is invoked.
  # on_help(option_parser: OptionParser)
  def on_help(&block)
    @help_handler = block
  end

  # Destructively parses args.
  #  - If the help option is invoked, if on_help handler is called.
  #  - In case of parsing error, the on_parse_error handler is called.
  # @param [Array] args argument array usually ARGV
  # @raise [OptionParser::ParseError] if @raise_on_parse_error is true (default false)
  def parse!(args, &_block)
    opt_parser.parse!(args)
    if options.empty?
      @help_handler.call(opt_parser) if @help_handler
    elsif block_given?
      yield options
    end
    options
  rescue OptionParser::ParseError => error
    @options = {}
    @parse_error_handler ? @parse_error_handler.call(error, opt_parser) : raise
  end

  def opt_parser
    @opt_parser ||= OptionParser.new do |opts|
      opts.on('--cmd COMMAND', 'Execute COMMAND') do |c|
        options[:command] = c
      end

      opts.on('--args a,b,c', Array, 'Arguments to command') do |args|
        options[:args] = args
      end

      opts.on('--format [FORMAT]', 'Format of output') do |format|
        options[:format] = format
      end

      opts.on_tail('-h', '--help', 'Show this help') do
        @options = {}
      end
    end
  end

  # Sets up default handlers.
  # - on_parse_error will print the error and usage to STDERR and exit with status 1
  # - on_help will print the usage to STDOUT and exit with status 0
  # @param [Boolean] system_exit default true. If true, the handlers exit after completion
  # @param [IO] stderr_dev pass an IO instance to have the STDERR written to it
  # @param [IO] stdout_dev pass an IO instance to have the STDOUT written to it
  # @return [Hailstorm::Cli::CmdParser] the instance for method chaining
  def with_default_handlers(system_exit = true, stderr_dev = STDERR, stdout_dev = STDOUT)
    on_parse_error do |error, parser|
      stderr_dev.puts error.reason
      stderr_dev.puts parser
      exit(1) if system_exit
    end

    on_help do |parser|
      stdout_dev.puts parser
      exit(0) if system_exit
    end

    self
  end
end
