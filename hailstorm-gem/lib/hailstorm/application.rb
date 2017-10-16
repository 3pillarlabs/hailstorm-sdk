# CLI application (default) for Hailstorm. This handles the application directory
# structure creation (via the hailstorm executable) and also implements the
# command processor (shell) invoked by the script/hailstorm executable.

# @author Sayantam Dey

require 'readline'
require 'terminal-table'

require 'hailstorm'
require 'hailstorm/exceptions'
require 'hailstorm/support/configuration'
require 'hailstorm/support/schema'
require 'hailstorm/support/thread'
require 'hailstorm/model/project'

require 'hailstorm/model/nmon'

require 'hailstorm/behavior/loggable'

class Hailstorm::Application

  include Hailstorm::Behavior::Loggable

  # Initialize the application and connects to the database
  # @param [String] app_name the application name
  # @param [String] boot_file_path full path to application config/boot.rb
  # @param [Hash] connection_spec map of properties for the database connection
  # @param [Hailstorm::Support::Configuration] env_config config object
  # @return nil
  def self.initialize!(app_name, boot_file_path, connection_spec = nil, env_config = nil)

    # in included gem version of i18n this value is set to null by default
    # this will switch to default locale if in case of invalid locale
    I18n.config.enforce_available_locales = true

    Hailstorm.app_name = app_name
    Hailstorm.root = File.expand_path('../..', boot_file_path)
    # set JAVA classpath
    # Add config/log4j.xml if it exists
    custom_log4j = File.join(Hailstorm.root, Hailstorm.config_dir, 'log4j.xml')
    if File.exists?(custom_log4j)
      $CLASSPATH << File.dirname(custom_log4j)
    end

    # Add all Java Jars and log4j.xml (will not be added if already added in above case) to classpath
    java_lib = File.expand_path('../java/lib', __FILE__)
    $CLASSPATH << java_lib
    Dir[File.join(java_lib, '*.jar')].each do |jar|
      require(jar)
    end
    java.lang.System.setProperty('hailstorm.log.dir',
                                 File.join(Hailstorm.root, Hailstorm.log_dir))

    ActiveRecord::Base.logger = logger
    Hailstorm.application = self.new
    Hailstorm.application.clear_tmp_dir()
    Hailstorm.application.check_for_updates()
    if env_config
      Hailstorm.application.config = env_config
    else
      Hailstorm.application.load_config(true)
    end
    Hailstorm.application.connection_spec = connection_spec
    Hailstorm.application.check_database()
  end

  # Constructor
  def initialize
    @multi_threaded = true
    @exit_command_counter = 0
  end

  # Initializes the application - creates directory structure and support files
  def create_project(invocation_path, arg_app_name, quiet = false, gem_path = nil)

    root_path = File.join(invocation_path, arg_app_name)
    FileUtils.mkpath(root_path)
    puts "(in #{invocation_path})" unless quiet
    puts "  created directory: #{arg_app_name}" unless quiet
    create_app_structure(root_path, arg_app_name, quiet, gem_path)
    puts '' unless quiet
    puts 'Done!' unless quiet

    return root_path
  end

  # Processes the user commands and options
  def process_commands

    logger.debug { ["\n", '*' * 80, "Application started at #{Time.now.to_s}", '-' * 80].join("\n") }
    # reload commands from saved history if such file exists
    reload_saved_history()

    puts %{Welcome to the Hailstorm (version #{Hailstorm::VERSION}) shell.
Type help to get started...
}
    trap("INT", proc { logger.warn("Type [quit|exit|ctrl+D] to exit shell") } )

    # for IRB like shell, save state for later execution
    shell_binding = FreeShell.new.get_binding()
    prompt = 'hs > '
    while @exit_command_counter >= 0

      command_line = Readline.readline(prompt, true)

      # process EOF (Control+D)
      if command_line.nil?
        unless exit_ok?
          @exit_command_counter += 1
          logger.warn {"You have running load agents: terminate first or quit/exit explicitly"}
        else
          puts "Bye"
          @exit_command_counter = -1
        end
      end

      # skip empty lines
      if command_line.blank?
        Readline::HISTORY.pop
        next
      end
      command_line.chomp!
      command_line.strip!

      begin
        command = interpret_command(command_line)
        unless command.nil?
          case command
            when :start
              prompt.gsub!(/\s$/, '*  ')
            when :stop, :abort
              prompt.gsub!(/\*\s{2}$/, ' ')
          end
        end

      rescue IncorrectCommandException => incorrect_command
        puts incorrect_command.message()

      rescue UnknownCommandException
        unless Hailstorm.env == :production
          # execute the command as-is like IRB
          begin
            out = shell_binding.eval(command_line)
            print '=> '
            if out.nil? or not out.is_a?(String)
              print out.inspect
            else
              print out
            end
            puts ''
          rescue Exception => irb_exception
            puts "[#{irb_exception.class.name}]: #{irb_exception.message}"
            logger.debug { "\n".concat(irb_exception.backtrace.join("\n")) }
          end
        else
          logger.error {"Unknown command: #{command_line}"}
        end

      rescue Hailstorm::ThreadJoinException
        logger.error "'#{command_line}' command failed."

      rescue Hailstorm::Exception => hailstorm_exception
        logger.error hailstorm_exception.message()

      rescue StandardError => uncaught
        logger.error uncaught.message
        logger.debug { "\n".concat(uncaught.backtrace.join("\n")) }
      ensure
        ActiveRecord::Base.clear_all_connections!
      end

      save_history(command_line)
    end
    puts ''
    logger.debug { ["\n", '-' * 80, "Application ended at #{Time.now.to_s}", '*' * 80].join("\n") }
  end

  def multi_threaded?
    @multi_threaded
  end

  def config(&block)

    @config ||= Hailstorm::Support::Configuration.new
    if block_given?
      yield @config
    else
      return @config
    end
  end

  attr_writer :config

  def check_database

    fail_once = false
    begin
      ActiveRecord::Base.establish_connection(connection_spec) # this is lazy, does not fail!
      # create/update the schema
      Hailstorm::Support::Schema.create_schema()

    rescue ActiveRecord::ActiveRecordError => e
      unless fail_once
        fail_once = true
        logger.info 'Database does not exist, creating...'
        # database does not exist yet
        create_database()
        retry
      else
        logger.error e.message()
        raise
      end
    ensure
      ActiveRecord::Base.clear_all_connections!
    end
  end

  def load_config(handle_load_error = false)

    begin
      @config = nil
      load(File.join(Hailstorm.root, Hailstorm.config_dir, 'environment.rb'))
      @config.freeze()
    rescue Object => e
      if handle_load_error
        logger.fatal(e.message())
      else
        raise(Hailstorm::Exception, e.message())
      end
    end
  end
  alias :reload :load_config

  def check_for_updates
    return unless Hailstorm.env == :production
    logger.debug 'Checking for updates...'
    new_version = Gem.latest_version_for('hailstorm')
    unless new_version.nil? or new_version.prerelease?
      current_version = Gem::Version.new(Hailstorm::VERSION)
      if current_version < new_version
        printf %{A new version of Hailstorm is available:
  Current version: #{current_version} (old)
  New version    : #{new_version}

Execute 'jruby -S bundle update' to install the updates.

Continue using old version?
(anything other than 'yes' will exit) > }
        prompt = $stdin.gets
        unless prompt.chomp == 'yes'
          exit(0)
        end
      end
    end
  end

  # Interpret the command (parse & execute)
  # @param [Array] args
  # @return [String] command or nil if help is invoked
  def interpret_command(*args)

    format = nil
    command = nil
    if args.last.is_a? Hash
      options = args.last
      ca = (options[:args] || []).join(' ')
      command = "#{options[:command]} #{ca}".strip.to_sym
      format = options[:format]
    else
      command = args.last.to_sym
    end

    if [:exit, :quit].include?(command)
      if @exit_command_counter == 0 and !exit_ok?
        @exit_command_counter += 1
        logger.warn {"You have running load agents: terminate first or #{command} again"}
      else
        puts 'Bye'
        @exit_command_counter = -1 # "express" exit
      end

    else
      @exit_command_counter = 0 # reset exit intention
      match_data = nil
      grammar.each do |rule|
        match_data = rule.match(command.to_s)
        break unless match_data.nil?
      end

      unless match_data.nil?
        method_name = match_data[1].to_sym
        method_args = match_data.to_a
                                .slice(2, match_data.length - 1)
                                .collect { |e| e.blank? ? nil : e }.compact.collect(&:strip)
        if method_args.length == 1 and method_args.first == 'help'
          help(method_name)
        else
          # defer to application for further processing
          method_args.push(format) unless format.nil?
          self.send(method_name, *method_args)
          return method_name
        end
      else
        raise(UnknownCommandException, "#{command} is unknown")
      end
    end
  end

  def clear_tmp_dir
    Dir["#{Hailstorm.tmp_path}/*"].each do |e|
      File.directory?(e) ? FileUtils.rmtree(e) : File.unlink(e)
    end
  end

  def logger=(new_logger)
    @logger = new_logger
  end

  def current_project
    Hailstorm::Model::Project.where(:project_code => Hailstorm.app_name)
    .first_or_create!()
  end

  # Writer for @connection_spec
  # @param [Hash] spec
  def connection_spec=(spec)
    @connection_spec = spec.symbolize_keys if spec
  end

  private

  def database_name()
    Hailstorm.app_name
  end

  def create_database()

    ActiveRecord::Base.establish_connection(connection_spec.merge(:database => nil))
    ActiveRecord::Base.connection.create_database(connection_spec[:database])
    ActiveRecord::Base.establish_connection(connection_spec)
  end

  def connection_spec

    if @connection_spec.nil?
      @connection_spec = {}

      # load the properties into a java.util.Properties instance
      database_properties_file = Java::JavaIo::File.new(File.join(Hailstorm.root,
                                                            Hailstorm.config_dir,
                                                            'database.properties'))
      properties = Java::JavaUtil::Properties.new()
      properties.load(Java::JavaIo::FileInputStream.new(database_properties_file))

      # load all properties without an empty value into the spec
      properties.each do |key, value|
        unless value.blank?
          @connection_spec[key.to_sym] = value
        end
      end

      # switch off multithread mode for sqlite & derby
      if @connection_spec[:adapter] =~ /(?:sqlite|derby)/i
        @multi_threaded = false
        @connection_spec[:database] = File.join(Hailstorm.root, Hailstorm.db_dir,
                                      "#{database_name}.db")
      else
        # set defaults which can be overridden
        @connection_spec = {
            :pool => 50,
            :wait_timeout => 30.minutes
        }.merge(@connection_spec).merge(:database => database_name)
      end
    end

    @connection_spec
  end

  # Creates the application directory structure and adds files at appropriate
  # directories
  # @param [String] root_path the path this application will be rooted at
  # @param [String] arg_app_name the argument provided for creating project
  # @param [Boolean] quiet
  def create_app_structure(root_path, arg_app_name, quiet = false, gem_path = nil)

    # create directory structure
    dirs = [
      Hailstorm.db_dir,
      Hailstorm.app_dir,
      Hailstorm.log_dir,
      Hailstorm.tmp_dir,
      Hailstorm.reports_dir,
      Hailstorm.config_dir,
      Hailstorm.vendor_dir,
      Hailstorm.script_dir
    ]

    dirs.each do |dir|
      FileUtils.mkpath(File.join(root_path, dir))
      puts "    created directory: #{File.join(arg_app_name, dir)}" unless quiet
    end

    skeleton_path = File.join(Hailstorm.templates_path, 'skeleton')

    # Process Gemfile - add additional platform specific gems
    engine = ActionView::Base.new()
    engine.assign({:jruby_pageant => !File::ALT_SEPARATOR.nil?,  # File::ALT_SEPARATOR is nil on non-windows
                   :gem_path => gem_path})
    File.open(File.join(root_path, 'Gemfile'), 'w') do |f|
      f.print(engine.render(:file => File.join(skeleton_path, 'Gemfile')))
    end
    puts "    wrote #{File.join(arg_app_name, 'Gemfile')}" unless quiet

    # Copy to script/hailstorm
    hailstorm_script = File.join(root_path, Hailstorm.script_dir, 'hailstorm')
    FileUtils.copy(File.join(skeleton_path, 'hailstorm'), hailstorm_script)
    FileUtils.chmod(0775, hailstorm_script) # make it executable
    puts "    wrote #{File.join(arg_app_name, Hailstorm.script_dir, 'hailstorm')}" unless quiet

    # Copy to config/environment.rb
    FileUtils.copy(File.join(skeleton_path, 'environment.rb'),
                   File.join(root_path, Hailstorm.config_dir))
    puts "    wrote #{File.join(arg_app_name, Hailstorm.config_dir, 'environment.rb')}" unless quiet

    # Copy to config/database.properties
    FileUtils.copy(File.join(skeleton_path, 'database.properties'),
                   File.join(root_path, Hailstorm.config_dir))
    puts "    wrote #{File.join(arg_app_name, Hailstorm.config_dir, 'database.properties')}" unless quiet

    # Process to config/boot.rb
    engine = ActionView::Base.new()
    engine.assign(:app_name => arg_app_name)
    File.open(File.join(root_path, Hailstorm.config_dir, 'boot.rb'), 'w') do |f|
      f.print(engine.render(:file => File.join(skeleton_path, 'boot')))
    end
    puts "    wrote #{File.join(arg_app_name, Hailstorm.config_dir, 'boot.rb')}" unless quiet
  end

  # Sets up the load agents and targets.
  # Creates the load agents as needed and pushes the Jmeter scripts to the agents.
  # Pushes the monitoring artifacts to targets.
  def setup(*args)

    force = (args.empty? ? false : true)
    current_project.setup(force)

    # output
    show_jmeter_plans()
    show_load_agents()
    show_target_hosts()
  end

  # Starts the load generation and monitoring on targets
  def start(*args)
    logger.info("Starting load generation and monitoring on targets...")
    redeploy = (args.empty? ? false : true)
    current_project.start(redeploy)

    show_load_agents()
    show_target_hosts()
  end

  # Stops the load generation and monitoring on targets and collects all logs
  def stop(*args)

    logger.info("Stopping load generation and monitoring on targets...")
    wait = args.include?('wait')
    options = (args.include?('suspend') ? {:suspend => true} : nil)
    current_project.stop(wait, options)

    show_load_agents()
    show_target_hosts()
  end

  def abort(*args)

    logger.info("Aborting load generation and monitoring on targets...")
    options = (args.include?('suspend') ? {:suspend => true} : nil)
    current_project.abort(options)

    show_load_agents()
    show_target_hosts()
  end

  def terminate(*args)

    logger.info("Terminating test cycle...")
    current_project.terminate()

    show_load_agents()
    show_target_hosts()
  end

  def results(*args)
    case args.length
      when 3
        operation, sequences, format = args
      when 2
        operation, sequences = args
      else
        operation, = args
    end
    operation = (operation || 'show').to_sym
    extract_last = false
    unless sequences.nil?
      if sequences == 'last'
        extract_last = true
        sequences = nil
      elsif sequences.match(/^(\d+)\-(\d+)$/) # range
        sequences = ($1..$2).to_a.collect(&:to_i)
      elsif sequences.match(/^[\d,:]+$/)
        sequences = sequences.split(/\s*[,:]\s*/).collect(&:to_i)
      else
        glob, opts = sequences.split(/\s+/).reduce([]) do |a, e|
          if e =~ /=/
            a.push({}) if a.last == nil or a.last.is_a?(String)
            k, v = e.split(/=/)
            a.last.merge!({k => v})
          else
            a.unshift(e)
          end
          a
        end
        if glob.is_a?(Hash)
          opts = glob
          glob = nil
        end
        unless opts.nil?
          opts.keys.each do |opt_key|
            unless [:jmeter, :exec, :cluster].include?(opt_key.to_sym)
              raise(Hailstorm::Exception, "Unknown results import option: #{opt_key}")
            end
          end
        end
        sequences = [glob, opts]
        logger.debug { "results(#{args}) -> #{sequences}" }
      end
    end
    data = current_project.results(operation, sequences)
    display_data = (extract_last && !data.empty?) ? [data.last] : data
    if :show == operation
      if format.nil?
        text_table = Terminal::Table.new()
        text_table.headings = ['TEST', 'Threads', '90 %tile', 'TPS', 'Started', 'Stopped']
        text_table.rows = display_data.collect do |execution_cycle|
          [
              execution_cycle.id,
              execution_cycle.total_threads_count,
              execution_cycle.avg_90_percentile,
              execution_cycle.avg_tps.round(2),
              execution_cycle.formatted_started_at,
              execution_cycle.formatted_stopped_at
          ]
        end

        puts text_table.to_s
      else
        puts display_data.reduce([]) {|acc, execution_cycle|
               acc.push({
                            :execution_cycle_id => execution_cycle.id,
                            :total_threads_count => execution_cycle.total_threads_count,
                            :avg_90_percentile => execution_cycle.avg_90_percentile,
                            :avg_tps => execution_cycle.avg_tps.round(2),
                            :started_at => execution_cycle.formatted_started_at,
                            :stopped_at => execution_cycle.formatted_stopped_at
                        })
             }.to_json
      end
    elsif :export == operation
      if format and :zip == format.to_sym
        reports_path = File.join(Hailstorm.root, Hailstorm.reports_dir)
        timestamp = Time.now.strftime('%Y%m%d%H%M%S')
        zip_file_path = File.join(reports_path, "jtl-#{timestamp}.zip")
        FileUtils.safe_unlink zip_file_path
        Zip::File.open(zip_file_path, Zip::File::CREATE) do |zf|
          data.each do
            # @type [Hailstorm::Model::ExecutionCycle] ex
            |ex|

            seq_dir = "SEQUENCE-#{ex.id}"
            zf.mkdir(seq_dir)
            Dir["#{reports_path}/#{seq_dir}/*.jtl"].each do |jtl_file|
              ze = "#{seq_dir}/#{File.basename(jtl_file)}"
              zf.add(ze, jtl_file) { true }
            end
          end
        end
      end
    end
  end

  # Implements the purge commands as per options
  def purge(*args)
    option = args.first || :tests
    case option.to_sym
      when :tests
        current_project.execution_cycles.each {|e| e.destroy()}
        logger.info "Purged all data for tests"
      when :clusters
        current_project.purge_clusters()
        logger.info "Purged all clusters"
      else
        current_project.destroy()
        logger.info "Purged all project data"
    end
  end

  def show(*args)
    what = (args.first || 'active').to_sym
    all = :all == args[1].to_s.to_sym || :all == what
    show_jmeter_plans(only_active = !all) if [:jmeter, :active, :all].include?(what)
    show_load_agents(only_active = !all)  if [:cluster, :active, :all].include?(what)
    show_target_hosts(only_active = !all) if [:monitor, :active, :all].include?(what)
  end

  def status(*args)

    format, = args
    unless current_project.current_execution_cycle.nil?
      running_agents = current_project.check_status()
      unless running_agents.empty?
        logger.info 'Load generation running on following load agents:'
        text_table = Terminal::Table.new()
        text_table.headings = ['Cluster', 'Agent', 'PID']
        text_table.rows = running_agents.collect {|agent|
          [agent.clusterable.slug, agent.public_ip_address, agent.jmeter_pid]
        }

        if format and format.to_sym == :json
          puts running_agents.to_json
        else
          puts text_table.to_s
        end

      else
        logger.info 'Load generation finished on all load agents'
        if format and format.to_sym == :json
          puts [].to_json
        end
      end
    else
      logger.info 'No tests have been started'
    end
  end

  # Process the help command
  def help(*args)

    help_on = args.first || :help
    print self.send("#{help_on}_options")
  end

  # Checks if there are no unterminated load_agents.
  # @return [Boolean] true if there are no unterminated load_agents
  def exit_ok?
    current_project.load_agents().empty?
  end


  # Defines the grammar for the rules
  def grammar

    @grammar ||= [
        Regexp.new('^(help)(\s+setup|\s+start|\s+stop|\s+abort|\s+terminate|\s+results|\s+purge|\s+show|\s+status)?$'),
        Regexp.new('^(setup)(\s+force|\s+help)?$'),
        Regexp.new('^(start)(\s+redeploy|\s+help)?$'),
        Regexp.new('^(stop)(\s+suspend|\s+wait|\s+suspend\s+wait|\s+wait\s+suspend|\s+help)?$'),
        Regexp.new('^(abort)(\s+suspend|\s+help)?$'),
        Regexp.new('^(results)(\s+show|\s+exclude|\s+include|\s+report|\s+export|\s+import|\s+help)?(\s+[\d,\-:]+|\s+last)?(.*)$'),
        Regexp.new('^(purge)(\s+tests|\s+clusters|\s+all|\s+help)?$'),
        Regexp.new('^(show)(\s+jmeter|\s+cluster|\s+monitor|\s+help|\s+active)?(|\s+all)?$'),
        Regexp.new('^(terminate)(\s+help)?$'),
        Regexp.new('^(status)(\s+help)?$')
    ]
  end

  def save_history(command)

    unless File.exists?(saved_history_path)
      FileUtils.touch(saved_history_path)
    end

    command_history = []
    command_history_size = (ENV['HAILSTORM_HISTORY_LINES'] || 1000).to_i
    File.open(saved_history_path, 'r') do |f|
      f.each_line {|l| command_history.push(l.chomp) unless l.blank? }
    end
    if command_history.size == command_history_size
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

  def show_jmeter_plans(only_active = true)
    jmeter_plans = []
    q = current_project.jmeter_plans
    q = q.active if only_active
    q.each do |jmeter_plan|
      plan = OpenStruct.new
      plan.name = jmeter_plan.test_plan_name
      plan.properties = jmeter_plan.properties_map()
      jmeter_plans.push(plan)
    end
    render_view('jmeter_plan', :jmeter_plans => jmeter_plans, :only_active => only_active)
  end

  def show_load_agents(only_active = true)

    clustered_load_agents = []
    current_project.clusters.each do |cluster|
      cluster.clusterables(all = !only_active).each do |clusterable|
        view_item = OpenStruct.new()
        view_item.clusterable_slug = clusterable.slug()
        view_item.terminal_table = Terminal::Table.new()
        view_item.terminal_table.headings = ['JMeter Plan', 'Type', 'IP Address', 'JMeter PID']
        q = clusterable.load_agents
        q = q.active if only_active
        q.each do |load_agent|
          view_item.terminal_table.add_row([
           load_agent.jmeter_plan.test_plan_name,
           (load_agent.master? ? 'Master' : 'Slave'),
           load_agent.public_ip_address,
           load_agent.jmeter_pid
          ])
        end
        clustered_load_agents.push(view_item)
      end
    end
    render_view('cluster', :clustered_load_agents => clustered_load_agents, :only_active => only_active)
  end

  def show_target_hosts(only_active = true)

    terminal_table = Terminal::Table.new()
    terminal_table.headings = ['Role', 'Host', 'Monitor', 'PID']
    q = current_project.target_hosts
    q = q.active if only_active
    target_hosts = q.natural_order
    target_hosts.each do |target_host|
      terminal_table.add_row([
                                 target_host.role_name,
                                 target_host.host_name,
                                 target_host.class.name.demodulize.tableize.singularize,
                                 target_host.executable_pid,
                             ])
    end
    render_view('monitor', :terminal_table => terminal_table, :only_active => only_active)
  end

  def render_view(template_file, context_vars = {})

    template_path = File.join(Hailstorm.templates_path, "cli")
    template_file_path = File.join(template_path, template_file)

    engine = ActionView::Base.new()
    engine.view_paths.push(template_path)
    engine.assign(context_vars)
    puts engine.render(:file => template_file_path, :formats => [:text], :handlers => [:erb])
  end


  def help_options()
    @help_options ||=<<-HELP

    Hailstorm shell accepts commands and associated options for a command.

    Commands:

    setup           Boot up load agents and setup target monitors.

    start           Starts load generation and target monitoring.

    stop            Stops load generation and target monitoring.

    abort           Aborts load generation and target monitoring.

    terminate       Terminates load generation and target monitoring.

    results         Include, exclude, export, import results or generate report

    purge           Purge specific or ALL data from database

    show            Show the environment configuration

    status          Show status of load generation across all agents

    help COMMAND    Show help on COMMAND
                    COMMAND help will also show help on COMMAND
    HELP
  end

  def setup_options()

    @setup_options ||=<<-SETUP

    Boot load agents and target monitors.
    Creates the load generation agents, sets up the monitors on the configured
    targets and deploys the JMeter scripts in the project "jmeter" directory
    to the load agents.

Options

    force         Force application setup, even when no environment changes
                  are detected.
    SETUP
  end

  def start_options()

    @start_options ||=<<-START

    Starts load generation and target monitoring. This will automatically
    trigger setup actions if you have modified the configuration. Additionally,
    if any JMeter plan is altered, the altered plans will be re-processed.
    However, modified datafiles and other support files (such as custom plugins)
    will not be re-deployed unless the redeploy option is specified.

Options

    redeploy      Re-deploy ALL JMeter scripts and support files to agents.
    START
  end

  def stop_options()

    @stop_options ||=<<-STOP

    Stops load generation and target monitoring.
    Fetch logs from the load agents and server. This does NOT terminate the load
    agents.

Options

    wait          Wait till JMeter completes.
    suspend       Suspend load agents (depends on cluster support).
    STOP
  end

  def abort_options

    @abort_options ||=<<-ABORT

    Aborts load generation and target monitoring.
    This does not fetch logs from the servers and does not terminate the
    load agents. This task is handy when you want to stop the current test
    because you probably realized there was a misconfiguration after starting
    the tests.

Options

    suspend       Suspend load agents (depends on cluster support).
    ABORT
  end

  def terminate_options

    @terminate_options ||=<<-TERMINATE

    Terminates load generation and target monitoring.
    Additionally, cleans up temporary state information on local filesystem.
    You should usually invoke this task at the end of your test run - although
    the system will allow you to execute this task at any point in your testing
    cycle. This also terminates the load agents.
    TERMINATE
  end

  def results_options

    @results_options ||=<<-RESULTS

    Show, include, exclude or generate report for one or more tests. Without any
    argument, all successfully stopped tests are operated on. The optional TEST
    argument can be a single test ID or a comma separated list of test IDs(4,7)
    or a hyphen separated list(1-3). The hyphen separated list is equivalent to
    explicity mentioning all IDs in comma separated form.

Options

      show    [TEST]  Displays successfully stopped tests (default).
              last    Displays the last successfully stopped tests
      exclude [TEST]  Exclude TEST from reports.
                      Without a TEST argument, no tests will be excluded.
      include [TEST]  Include TEST in reports.
                      Without a TEST, no tests will be included.
      report  [TEST]  Generate report for TEST.
                      Without a TEST argument, all successfully stopped tests will
                      be reported.
      export  [TEST]  Export the results as one or more JTL files.
                      Without a TEST argument, all successfully stopped tests
                      will be exported.
      import  <FILE>  Import the results from FILE(.jtl). OPTS is a set of
              [OPTS]  key value pairs, specified as key=value and multiple pairs
                      are separated by whitespace. Known keys and when they are
                      needed:
                      jmeter=<plan name>   # required if there are multiple plans
                      cluster=<cluster id> # required if there are multiple clusters
                      exec=<execution id>  # required if the data is to be imported
                                             to an existing execution cycle
    RESULTS
  end

  def show_options()

    @show_options ||=<<-SHOW

    Show how the environment is currently configured. Without any option,
    it will show the current configuration for all the environment components.

Options

    jmeter        Show jmeter configuration
    cluster       Show cluster configuration
    monitor       Show monitor configuration
    active        Show everything active (default)
    all           Special switch to show inactive items
                  > show all
                  > show jmeter all
    SHOW
  end

  def purge_options()

    @purge_options ||=<<-PURGE

    Purge  (remove) all or specific data from the database. You can invoke this
    commmand anytime you want to start over from scratch or remove data for old
    tests. If executed without any options, will only remove data for tests.

    WARNING: The data removed will be unrecoverable!

Options

    tests         Purge the data for all tests (default)
    clusters      Purge the cluster information and artifacts.
                  Outcome depends on the type of the cluster, for Amazon,
                  this means ALL Hailstorm related infrastructure for the
                  account will be deleted. This is a bad idea if you are using
                  a shared account, harmless otherwise, since all required
                  infrastructure is created on-demand. It is recommended to
                  use this command _only_ when suggested by diagnostic messages.
    all           Purge ALL data
    PURGE
  end

  def status_options()

    @status_options ||=<<-STATUS

    Show the current state of load generation across all agents. If load
    generation is currently executing on any agent, such agents are displayed.
    STATUS
  end


  class UnknownCommandException < Hailstorm::Exception
  end

  class IncorrectCommandException < Hailstorm::Exception
  end

  class FreeShell

    def get_binding()
      binding()
    end
  end

end
