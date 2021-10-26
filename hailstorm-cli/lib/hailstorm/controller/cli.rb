# frozen_string_literal: true

require 'readline'

require 'hailstorm/controller'
require 'hailstorm/controller/application'
require 'hailstorm/version'
require 'hailstorm/exceptions'
require 'hailstorm/cli/cmd_history'
require 'hailstorm/cli/cmd_executor'
require 'hailstorm/local_file_store'

# CLI controller
class Hailstorm::Controller::Cli

  include Hailstorm::Controller::Application

  attr_reader :shell_binding_ctx

  attr_accessor :exit_command_counter,
                :prompt

  # Create a new CLI instance
  # @param [Hailstorm::Middleware::Application] args arguments
  def initialize(*args)
    super
    self.exit_command_counter = 0
    self.prompt = 'hs > '
    @shell_binding_ctx = FreeShell.new.binding_context
    Hailstorm.fs = Hailstorm::LocalFileStore.new
  end

  def current_project
    @current_project ||= Hailstorm::Model::Project.where(project_code: Hailstorm.app_name).first_or_create!
  end

  # Processes the user commands and options
  def process_commands
    logger.debug { ["\n", '*' * 80, "Application started at #{Time.now}", '-' * 80].join("\n") }

    puts %{Welcome to the Hailstorm shell (v.#{Hailstorm::Cli::VERSION}, gem v.#{Hailstorm::VERSION} ).
Type help to get started...
}
    trap('INT', proc { logger.warn('Type [quit|exit|ctrl+D] to exit shell') })

    start_cmd_loop
    puts ''
    logger.debug { ["\n", '-' * 80, "Application ended at #{Time.now}", '*' * 80].join("\n") }
  end

  def process_cmd_line(*args)
    current_serial_version = middleware.config_serial_version
    if settings_modified?(current_serial_version)
      middleware.load_config
      current_project.settings_modified = true
      current_project.serial_version = current_serial_version
      cmd_executor.refresh_config
    end
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
      logger.debug { error.backtrace.prepend("\n").join("\n") }
    end
  end

  def post_process(method_name)
    handle_exit(method_name) if %i[quit exit].include?(method_name)
    return unless current_project.destroyed?

    @current_project = nil
    cmd_executor.project = current_project
  end

  def handle_unknown_command(instr)
    if Hailstorm.production?
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
      logger.debug { irb_exception.backtrace.prepend("\n").join("\n") }
    end
  end

  def start_cmd_loop
    # reload commands from saved history if such file exists
    cmd_history.reload_saved_history

    # for IRB like shell, save state for later execution
    while self.exit_command_counter >= 0
      command_line = Readline.readline(enhanced_prompt, true)

      # process EOF (Control+D)
      handle_exit if command_line.nil?

      # skip empty lines
      if command_line.blank?
        cmd_history.pop
        next
      end

      command_line = command_line.chomp.strip
      process_cmd_line(command_line)
      cmd_history.save_history(command_line)
    end
  end

  def enhanced_prompt
    if self.current_project&.current_execution_cycle
      self.prompt.gsub(/\s$/, '*  ')
    else
      self.prompt
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

  # @param [String] current_serial_version Current serial version, however it is computed
  # @return [Boolean] true if configuration settings have been modified
  def settings_modified?(current_serial_version)
    current_project.serial_version.nil? || current_project.serial_version != current_serial_version
  end

  # Simple shell for executing code within the Hailstorm shell
  class FreeShell
    def binding_context
      binding
    end
  end
end
