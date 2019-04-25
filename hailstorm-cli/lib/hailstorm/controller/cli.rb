require 'readline'

require 'hailstorm/controller'
require 'hailstorm/controller/application'
require 'hailstorm/version'
require 'hailstorm/exceptions'
require 'hailstorm/cli/cmd_history'
require 'hailstorm/cli/cmd_executor'

# CLI controller
class Hailstorm::Controller::Cli

  include Hailstorm::Controller::Application

  attr_reader :shell_binding_ctx

  attr_accessor :exit_command_counter
  attr_accessor :prompt

  # Create a new CLI instance
  # @param [Hailstorm::Middleware::Application] args arguments
  def initialize(*args)
    super
    self.exit_command_counter = 0
    self.prompt = 'hs > '
    @shell_binding_ctx = FreeShell.new.binding_context
  end

  def current_project
    @current_project ||= Hailstorm::Model::Project.where(project_code: Hailstorm.app_name).first_or_create!
  end

  # Processes the user commands and options
  def process_commands
    logger.debug { ["\n", '*' * 80, "Application started at #{Time.now}", '-' * 80].join("\n") }

    puts %{Welcome to the Hailstorm (version #{Hailstorm::VERSION}) shell.
Type help to get started...
}
    trap('INT', proc { logger.warn('Type [quit|exit|ctrl+D] to exit shell') })

    start_cmd_loop
    puts ''
    logger.debug { ["\n", '-' * 80, "Application ended at #{Time.now}", '*' * 80].join("\n") }
  end

  def process_cmd_line(*args)
    post_process(cmd_executor.interpret_execute(args))
  rescue StandardError => error
    handle_error(args, error)
  ensure
    ActiveRecord::Base.clear_all_connections!
  end

  def cmd_history
    @cmd_history ||= Hailstorm::Cli::CmdHistory.new(Readline::HISTORY)
  end

  def cmd_executor
    @cmd_executor ||= Hailstorm::Cli::CmdExecutor.new(middleware, current_project)
  end

  private

  def handle_error(args, error)
    case error.class.name
    when Hailstorm::UnknownCommandException.name
      handle_unknown_command(args.last.to_s)
    when Hailstorm::Exception.name
      logger.error "'#{args}' command failed: #{error.message}"
    else
      logger.error error.message
      logger.debug { "\n".concat(error.backtrace.join("\n")) }
    end
  end

  def post_process(method_name)
    handle_exit(method_name) if %i[quit exit].include?(method_name)
    modify_prompt_on(method_name)
  end

  def modify_prompt_on(method_name)
    case method_name
    when :start
      self.prompt.gsub!(/\s$/, '*  ')
    when :stop, :abort
      self.prompt.gsub!(/\*\s{2}$/, ' ')
    end
  end

  def handle_unknown_command(instr)
    if Hailstorm.is_production?
      logger.error { "Unknown command: #{instr}" }
      return
    end
    # execute the command as-is like IRB
    begin
      out = shell_binding_ctx.eval(instr)
      print '=> '
      puts out.inspect
    rescue ::Exception => irb_exception
      puts "[#{irb_exception.class.name}]: #{irb_exception.message}"
      logger.debug { "\n".concat(irb_exception.backtrace.join("\n")) }
    end
  end

  def start_cmd_loop
    # reload commands from saved history if such file exists
    cmd_history.reload_saved_history

    # for IRB like shell, save state for later execution
    while self.exit_command_counter >= 0
      command_line = Readline.readline(self.prompt, true)

      # process EOF (Control+D)
      handle_exit if command_line.nil?

      # skip empty lines
      if command_line.blank?
        cmd_history.pop
        next
      end
      command_line.chomp!
      command_line.strip!

      process_cmd_line(command_line)
      cmd_history.save_history(command_line)
    end
  end

  # Checks if there are no unterminated load_agents.
  # @return [Boolean] true if there are no unterminated load_agents
  def exit_ok?
    current_project.load_agents.empty?
  end

  # Truth table
  #   command.nil?  | 1 1 1 1 0 0 0 0
  #   counter == 0  | 1 1 0 0 1 1 0 0
  #   exit_ok?      | 1 0 1 0 1 0 1 0
  #   -------------------------------
  #   R             | 1 0 x 0 1 0 1 1
  #   R = abc + a'bc + a'b'c + a'b'c'
  #     = (a + a')bc + a'b'(c + c')
  #     = bc + a'b'
  def handle_exit(command = nil)
    exit_ok_flag = (self.exit_command_counter.zero? && exit_ok?) || (command && self.exit_command_counter != 0)
    if exit_ok_flag
      puts 'Bye'
      self.exit_command_counter = -1
    else
      self.exit_command_counter += 1
      logger.warn { 'You have running load agents: terminate first or quit/exit explicitly' }
    end
  end

  # Simple shell for executing code within the Hailstorm shell
  class FreeShell
    def binding_context
      binding
    end
  end
end
