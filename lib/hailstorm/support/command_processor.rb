# Processes user commands and options and delegates to application instance
# methods.
# @author Sayantam Dey

require 'optparse'
require 'hailstorm/support'

class Hailstorm::Support::CommandProcessor
  
  attr_reader :args
  
  def initialize
    @args = ARGV.clone
  end
  
  # executes the user commands. The commands are obtained from ARGV.
  def execute()
    
    # process -v, -h
    args.clone.each do |arg|
      
      if ['-v', '--verbose'].include?(arg)
        args.delete(arg)
        Hailstorm.logger.level = Logger::DEBUG
      end
      
      if ['-h', '--help'].include?(arg)
        puts commands_doc()
        exit
      end
    end
    
    commands = []
    args.each do |arg|
      if [:help, :shell].include?(arg.to_sym) or application.respond_to?(arg.to_sym)
        commands.push(arg.to_sym)
      end
    end
  	
  	if commands.size == 0
      commands.push(:shell)
  	end
  	
  	# there should only be one command unless it is help on a command
  	if commands.size > 1
  	  unless commands.size == 2 and commands.include?(:help)
        $stderr.puts "Can not process multiple commands!"
        $stderr.puts commands_doc()
        exit(2)
  	  end
  	end
    
    if commands.include?(:help)
      help_on_command = commands.last 
			if help_on_command == :help
        $stderr.puts "You switched order of help COMMAND!"
        $stderr.puts commands_doc()
        exit(3)
			end
      unless respond_to?("#{help_on_command}_options")
        $stderr.puts "Unknown command: #{help_on_command}"
        $stderr.puts commands_doc()
        exit(3)
      end
			puts send("#{help_on_command}_options") || "No help"
			exit
    
    elsif commands.include?(:shell)
      require('readline')

      # reload commands from saved history if such file exists
      reload_saved_history()

      puts "Welcome to the Hailstorm shell. Type help to get started..."
      trap("INT", proc { puts "Type [quit|exit|ctrl+D] to exit shell" } )
      shell_binding = binding()
      while command = Readline.readline("hs > ", true)
        # skip empty lines
        if command.blank?
          Readline::HISTORY.pop
          next
        end

        command.chomp!
        command.strip!
        if [:exit, :quit].include?(command.to_sym)
          puts "Bye"
          exit 0
    
        elsif command =~ /^verbose\s+(on|off)$/
          
          if :on == $1.to_sym
            Hailstorm.logger.level = Logger::DEBUG
          else
            Hailstorm.logger.level = Logger::INFO
          end
          
        elsif :help == command.to_sym
          puts commands_doc()
        
        elsif /^help\s+(.+?)$/ =~ command
          help_on_command = $1
          if respond_to?("#{help_on_command}_options")
            puts send("#{help_on_command}_options")
          else
            puts "unknown command"
          end
        elsif :reload == command.to_sym
          application.reload()
        else
          begin
            app_cmd = command.split(/\s+/).first
            
            if respond_to?("#{app_cmd}_options")
              send("#{app_cmd}_options").parse!(command.split(/\s+/))
              @aborted = true if :abort == app_cmd.to_sym
              application.send(app_cmd)
              application.instance_variable_set("@current_project", nil) # hack
            else  
              out = shell_binding.eval(command)
              print '=> '
              if out.nil? or not out.is_a?(String)
                print out.inspect
              else
                print out
              end
              puts ''
            end
            
          rescue Hailstorm::Error, Hailstorm::Exception => e
            puts "[FAILED] #{e}"
            logger.debug { "\n".concat(e.backtrace.join("\n")) }
          rescue Exception => e
            puts "[#{e.class.name}] #{e.message}"
            logger.debug { "\n".concat(e.backtrace.join("\n")) }
          ensure
            self.instance_variables.each do |ivar|
              instance_variable_set(ivar, nil) unless ivar == :@args
            end
          end
        end
        save_history(command)
      end
      puts ""
    else
      command = commands.first
      command_options = send("#{command}_options")
      command_options.parse!(args)
      
      # now args should only have the command
      @aborted = true if :abort == command.to_sym
      application.send(command)
    end
  end

  def setup_options()

    @setup_options ||= OptionParser.new() do |opts|
      
      opts.banner =<<-SETUP
    Boot load agents and target monitors.
    Creates the load generation agents, sets up the monitors on the configured
    targets and deploys the JMeter scripts in the project app folder to the
    load agents. This task should only be executed after the config
    task is executed.
			SETUP

      opts.separator ''
			opts.separator 'Setup Options'

			opts.on('-f', '--force', 'Force application setup') do
				@force_setup = true
      end
    end
  end

  def start_options()

    @start_options ||= OptionParser.new() do |opts|
      
      opts.banner =<<-START
    Starts load generation and target monitoring. This will automatically trigger
    setup actions if you have modified the configuration. Additionally, if any
    JMeter plan is altered, the altered plans will be re-processed.
			START

      opts.separator ''
			opts.separator 'Start Options'

			opts.on('-r', '--re-deploy', 'Re-deploy ALL JMeter scripts to agents') do
				@redeploy = true
			end
    end
  end

  def stop_options()

    @stop_options ||= OptionParser.new() do |opts|
      
      opts.banner =<<-STOP
    Stops load generation and target monitoring.
    Fetch logs from the load agents and server. This does NOT terminate the load
    agents.
			STOP

      opts.separator ''
			opts.separator 'Stop Options'
      
      opts.on('-w', '--wait', 'Wait till JMeter completes') do
        @wait_for_jmeter = true
      end
      
			opts.on('-s', '--suspend', 'Suspend load agents (depends on cluster support)') do
				@suspend_load_agents = true
			end
    end
  end

	def abort_options

    @abort_options ||= OptionParser.new() do |opts|
      
      opts.banner =<<-ABORT
    Aborts load generation and target monitoring.
    This does not fetch logs from the servers and does not terminate the
    load agents. This task is handy when you want to stop the current test
    because you probably realized there was a misconfiguration after starting
    the tests.
			ABORT

      opts.separator ''
			opts.separator 'Abort Options'

			opts.on('-s', '--suspend', 'Suspend load agents (depends on cluster support)') do
				@suspend_load_agents = true
			end
    end
	end

	def terminate_options

    @terminate_options ||= OptionParser.new() do |opts|
      
      opts.banner =<<-TERMINATE
    Terminates load generation and target monitoring.
    Additionally, cleans up temporary state information on local filesystem.
    You should usually invoke this task at the end of your test run - although
    the system will allow you to execute this task at any point in your testing
    cycle. This also terminates the load agents.
			TERMINATE

      #opts.separator ''
			#opts.separator 'Terminate Options'

    end
	end

  def report_options

    @report_options ||= OptionParser.new() do |opts|

      opts.banner =<<-REPORT
    Generates a report of successfully stopped tests. Tests which were aborted
    are not considered.
      REPORT

      opts.separator ''
      opts.separator 'Report Options'

      opts.on('--show-tests', 'Displays tests to be included in report') do
        @report_show_tests = true
      end

      opts.on('--exclude SEQUENCE', 'Exclude SEQUENCE test from report') do |sequence|

        @report_exclude_sequence = sequence
      end

      opts.on('--include SEQUENCE', 'Include SEQUENCE test in report') do |sequence|
        @report_include_sequence = sequence
      end

      opts.on('--tests SEQ 1,SEQ 2,SEQ 3', Array,
              'Include listed sequences in report') do |list|
        @report_sequence_list = list
      end

      opts.on('--finalize', 'Tests in generated report be marked as reported',
              'These tests will not appear in next report') do
        @report_finalize = true
      end

    end
  end

  def show_options()

    @show_options ||= OptionParser.new() do |opts|

      opts.banner =<<-SHOW
    Show how the environment is currently configured. Without any option,
    it will show the current configuration for the environment variables.
      SHOW

      opts.separator ''
      opts.separator 'Show Options'

      opts.on('--jmeter', 'Show jmeter configuration') { @show_setup = :jmeter }
      opts.on('--cluster', 'Show cluster configuration') { @show_setup = :cluster }
      opts.on('--monitor', 'Show monitor configuration') { @show_setup = :monitor }
      opts.on('--status', 'Show load generation status') { @show_setup = :status }
    end
  end

  def purge_options()

    @purge_options ||= OptionParser.new() do |opts|

      opts.banner =<<-PURGE
    Purge  (remove) all or specific data from the database. You can invoke this
    commmand anytime you want to start over from scratch or remove data for old
    tests. If executed without any options, will only remove data for tests.

    WARNING: The data removed will be unrecoverable!
      PURGE

      opts.separator ''
      opts.separator 'Purge Options'

      opts.on('--tests', 'Purge the data for all tests') { @purge_item = :tests }
      opts.on('--all', 'Purge all data') { @purge_item = :all }
    end
  end

  def force_setup?
    @force_setup
  end

  def show_setup
    @show_setup || :all
  end

  def suspend_load_agents?
    @suspend_load_agents
  end

  def redeploy?
    @redeploy
  end

  def aborted?
    @aborted
  end

  def wait_for_jmeter?
    @wait_for_jmeter
  end

  def report_format
    @report_format || 'docx'
  end

  def report_show_tests?
    @report_show_tests
  end

  def report_exclude_sequence
    @report_exclude_sequence
  end

  def report_include_sequence
    @report_include_sequence
  end

  def report_sequence_list
    @report_sequence_list
  end

  def report_finalize?
    @report_finalize
  end

  def purge_item
    @purge_item || :tests
  end

  def application
    Hailstorm.application
  end
  
  def commands_doc
    if @commands_doc.nil?
      @commands_doc =<<HERE
Commands:
 
  setup           Boot up load agents and setup target monitors.

  start           Starts load generation and target monitoring.

  stop            Stops load generation and target monitoring.

  abort           Aborts load generation and target monitoring.

  terminate       Terminates load generation and target monitoring.

  report          Generates a report of stopped tests

  purge           Purge specific or ALL data from database

  show            Show the environment configuration

  help COMMAND    Show help on COMMAND

HERE
    end
    @commands_doc
  end

  def save_history(command)

    unless File.exists?(saved_history_path)
      FileUtils.touch(saved_history_path)
    end

    command_history = []
    File.open(saved_history_path, 'r') do |f|
      f.each_line {|l| command_history.push(l.chomp) unless l.blank? }
    end
    if command_history.size == 1000
      command_history.shift()
    end
    if command_history.empty? or command_history.last != command
      command_history.push(command.chomp)
      if command_history.size == 1000
        File.open(saved_history_path, 'w') do |f|
          command_history.each {|c| f.puts(c)}
        end
      else
        File.open(saved_history_path, 'a') do |f|
          f.puts(command)
        end
      end
    end
  end

  def reload_saved_history()

    if File.exists?(saved_history_path)
      File.open(saved_history_path, 'r') do |f|
        f.each_line {|l| Readline::HISTORY.push(l.chomp) }
      end
    end
  end

  def saved_history_path()
    File.join(java.lang.System.getProperty('user.home'), '.hailstorm_history')
  end

end
