require 'readline'

require 'hailstorm/controller'
require 'hailstorm/controller/application'
require 'hailstorm/version'
require 'hailstorm/exceptions'
require 'hailstorm/cli/help_doc'
require 'hailstorm/cli/view_template'
require 'hailstorm/middleware/command_execution_template'

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

  def help_doc
    @help_doc ||= Hailstorm::Cli::HelpDoc.new
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
      elsif method_name == :show
        show(*method_args)
      elsif method_name == :help
        help(*method_args)
      else
        values = command_execution_template.send(method_name, *method_args)
        render_method = "render_#{method_name}".to_sym
        render_args = values.is_a?(Array) ? values : [values]
        if respond_to?(render_method)
          self.send(render_method, *render_args)
        else
          render_default(*render_args)
        end
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

  def command_execution_template
    @command_execution_template ||= Hailstorm::Middleware::CommandExecutionTemplate.new(current_project)
  end

  def view_template
    @view_template ||= Hailstorm::Cli::ViewTemplate.new
  end

  def render_default(*_args)
    puts view_template.render_load_agents(current_project.clusters)
    puts view_template.render_target_hosts(current_project.target_hosts.active.natural_order)
  end

  def render_setup(*_args)
    puts view_template.render_jmeter_plans(current_project.jmeter.active)
    render_default
  end

  def render_results(*args)
    data, operation, format = args
    puts(view_template.render_results_show(data, format)) if operation == :show
  end

  def render_status(*args)
    running_agents, format = args
    if running_agents
      if !running_agents.empty?
        logger.info 'Load generation running on following load agents:'
        puts view_template.render_running_agents(running_agents, format)
      else
        logger.info 'Load generation finished on all load agents'
        puts [].to_json if format.to_s.to_sym == :json
      end
    else
      logger.info 'No tests have been started'
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

  def show(*args)
    what = (args.first || 'active').to_sym
    all = args[1].to_s.to_sym == :all || what == :all
    q = %i[jmeter_plans clusters target_hosts].reduce({}) do |s, e|
      _q = all ? current_project.send(e) : current_project.send(e).active
      s.merge(e => _q)
    end
    q[:target_hosts] = q[:target_hosts].natural_order
    should_show = -> (kind) { what == kind ||  %i[active all].include?(what) }
    puts view_template.render_jmeter_plans(q[:jmeter_plans], !all) if should_show.call(:jmeter)
    puts view_template.render_load_agents(q[:clusters], !all)  if should_show.call(:cluster)
    puts view_template.render_target_hosts(q[:target_hosts], !all) if should_show.call(:monitor)
  end

  # Simple shell for executing code within the Hailstorm shell
  class FreeShell
    def binding_context
      binding
    end
  end
end
