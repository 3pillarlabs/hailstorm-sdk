require 'readline'

require 'hailstorm/controller'
require 'hailstorm/controller/application'
require 'hailstorm/behavior/loggable'
require 'hailstorm/version'
require 'hailstorm/exceptions'
require 'hailstorm/cli/help_doc'

# CLI controller
class Hailstorm::Controller::Cli

  include Hailstorm::Controller::Application

  attr_reader :shell_binding_ctx

  attr_writer :help_doc

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

  def help_doc
    @help_doc ||= Hailstorm::Cli.HelpDoc.new
  end

  # Processes the user commands and options
  def process_commands
    logger.debug { ["\n", '*' * 80, "Application started at #{Time.now}", '-' * 80].join("\n") }
    # reload commands from saved history if such file exists
    reload_saved_history

    puts %{Welcome to the Hailstorm (version #{Hailstorm::VERSION}) shell.
Type help to get started...
}
    trap('INT', proc { logger.warn('Type [quit|exit|ctrl+D] to exit shell') })

    start_cmd_loop
    puts ''
    logger.debug { ["\n", '-' * 80, "Application ended at #{Time.now}", '*' * 80].join("\n") }
  end

  def process_cmd_line(*args)
    begin
      command_args = self.middleware
                         .command_interpreter
                         .interpret_command(*args)
                         .partition
                         .with_index { |_e, i| i == 0 }
      method_name = command_args[0].first
      method_args = command_args[1]
      if %i[quit exit].include?(method_name)
        handle_exit(method_name)
      else
        send(method_name, *method_args)
      end
      case method_name
        when :start
          self.prompt.gsub!(/\s$/, '*  ')
        when :stop, :abort
          self.prompt.gsub!(/\*\s{2}$/, ' ')
        else
          # no action
      end
    rescue Hailstorm::UnknownCommandException
      instr = args.last.to_s
      if !Hailstorm.is_production?
        # execute the command as-is like IRB
        begin
          out = shell_binding_ctx.eval(instr)
          print '=> '
          puts out.inspect
        rescue ::Exception => irb_exception
          puts "[#{irb_exception.class.name}]: #{irb_exception.message}"
          logger.debug {"\n".concat(irb_exception.backtrace.join("\n"))}
        end
      else
        logger.error {"Unknown command: #{instr}"}
      end
    rescue Hailstorm::ThreadJoinException
      logger.error "'#{args}' command failed."
    rescue Hailstorm::Exception => hailstorm_exception
      logger.error hailstorm_exception.message
    rescue StandardError => uncaught
      logger.error uncaught.message
      logger.debug {"\n".concat(uncaught.backtrace.join("\n"))}
    ensure
      ActiveRecord::Base.clear_all_connections!
    end
  end

  private

  def start_cmd_loop
    # for IRB like shell, save state for later execution
    while self.exit_command_counter >= 0
      command_line = Readline.readline(self.prompt, true)

      # process EOF (Control+D)
      handle_exit if command_line.nil?

      # skip empty lines
      if command_line.blank?
        Readline::HISTORY.pop
        next
      end
      command_line.chomp!
      command_line.strip!

      process_cmd_line(command_line)

      save_history(command_line)
    end
  end

  # Checks if there are no unterminated load_agents.
  # @return [Boolean] true if there are no unterminated load_agents
  def exit_ok?
    current_project.load_agents.empty?
  end

  def reload_saved_history
    return unless File.exist?(saved_history_path)
    File.open(saved_history_path, 'r') do |f|
      f.each_line { |l| Readline::HISTORY.push(l.chomp) }
    end
  end

  def saved_history_path
    File.join(java.lang.System.getProperty('user.home'), '.hailstorm_history')
  end

  def save_history(command)
    unless File.exist?(saved_history_path)
      FileUtils.touch(saved_history_path)
    end

    command_history = []
    command_history_size = (ENV['HAILSTORM_HISTORY_LINES'] || 1000).to_i
    File.open(saved_history_path, 'r') do |f|
      f.each_line { |l| command_history.push(l.chomp) unless l.blank? }
    end
    command_history.shift if command_history.size == command_history_size
    if command_history.empty? || (command_history.last != command)
      command_history.push(command.chomp)
      if command_history.size == 1000
        File.open(saved_history_path, 'w') do |f|
          command_history.each { |c| f.puts(c) }
        end
      else
        File.open(saved_history_path, 'a') do |f|
          f.puts(command)
        end
      end
    end
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
    exit_ok_flag = (self.exit_command_counter == 0 && exit_ok?) || (command && self.exit_command_counter != 0)
    if exit_ok_flag
      puts 'Bye'
      self.exit_command_counter = -1
    else
      self.exit_command_counter += 1
      logger.warn { 'You have running load agents: terminate first or quit/exit explicitly' }
    end
  end

  # Process the help command
  def help(help_on = :help)
    print help_doc.send("#{help_on}_options".to_sym)
  end

  # Simple shell for executing code within the Hailstorm shell
  class FreeShell
    def binding_context
      binding
    end
  end
end
