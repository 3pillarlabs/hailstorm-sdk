require 'readline'
require 'terminal-table'

require 'hailstorm/controller'
require 'hailstorm/exceptions'
require 'hailstorm/behavior/loggable'
require 'hailstorm/model/project'
require 'hailstorm/model/nmon'
require 'hailstorm/support/configuration'

# Base controller
# @author Sayantam Dey
module Hailstorm::Controller::Application

  include Hailstorm::Behavior::Loggable

  attr_reader :middleware

  # Create a new CLI instance
  # @param [Hailstorm::Middleware::Application] middleware instance
  def initialize(middleware)
    @middleware = middleware
  end

  def current_project
    @current_project ||= Hailstorm::Model::Project.where(project_code: Hailstorm.app_name).first_or_create!
  end

  # Sets up the load agents and targets.
  # Creates the load agents as needed and pushes the Jmeter scripts to the agents.
  # Pushes the monitoring artifacts to targets.
  def setup(*args)
    force = args.empty? ? false : true
    current_project.setup(force)

    # output
    show_jmeter_plans
    show_load_agents
    show_target_hosts
  end

  # Starts the load generation and monitoring on targets
  def start(*args)
    logger.info('Starting load generation and monitoring on targets...')
    redeploy = args.empty? ? false : true
    current_project.start(redeploy)

    show_load_agents
    show_target_hosts
  end

  # Stops the load generation and monitoring on targets and collects all logs
  def stop(*args)
    logger.info('Stopping load generation and monitoring on targets...')
    wait = args.include?('wait')
    options = { suspend: true } if args.include?('suspend')
    current_project.stop(wait, options)

    show_load_agents
    show_target_hosts
  end

  def abort(*args)
    logger.info('Aborting load generation and monitoring on targets...')
    options = { suspend: true } if args.include?('suspend')
    current_project.abort(options)

    show_load_agents
    show_target_hosts
  end

  def terminate(*_args)
    logger.info('Terminating test cycle...')
    current_project.terminate

    show_load_agents
    show_target_hosts
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
      elsif sequences =~ /^(\d+)-(\d+)$/ # range
        sequences = (Regexp.last_match(1)..Regexp.last_match(2)).to_a.collect(&:to_i)
      elsif sequences =~ /^[\d,:]+$/
        sequences = sequences.split(/\s*[,:]\s*/).collect(&:to_i)
      else
        glob, opts = sequences.split(/\s+/).each_with_object([]) do |e, a|
          if e =~ /=/
            a.push({}) if a.last.nil? || a.last.is_a?(String)
            k, v = e.split(/=/)
            a.last.merge!({ k => v })
          else
            a.unshift(e)
          end
        end
        if glob.is_a?(Hash)
          opts = glob
          glob = nil
        end
        unless opts.nil?
          opts.keys.each do |opt_key|
            unless %i[jmeter exec cluster].include?(opt_key.to_sym)
              raise(Hailstorm::Exception, "Unknown results import option: #{opt_key}")
            end
          end
        end
        sequences = [glob, opts]
        logger.debug { "results(#{args}) -> #{sequences}" }
      end
    end
    data = current_project.results(operation, sequences)
    display_data = extract_last && !data.empty? ? [data.last] : data
    if operation == :show
      if format.nil?
        text_table = Terminal::Table.new
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
        list = display_data.reduce([]) do |acc, execution_cycle|
          attrs = {
            execution_cycle_id: execution_cycle.id,
            total_threads_count: execution_cycle.total_threads_count,
            avg_90_percentile: execution_cycle.avg_90_percentile,
            avg_tps: execution_cycle.avg_tps.round(2),
            started_at: execution_cycle.formatted_started_at,
            stopped_at: execution_cycle.formatted_stopped_at
          }
          acc.push(attrs)
        end
        puts list.to_json
      end
    elsif operation == :export
      if format && format.to_sym == :zip
        reports_path = File.join(Hailstorm.root, Hailstorm.reports_dir)
        timestamp = Time.now.strftime('%Y%m%d%H%M%S')
        zip_file_path = File.join(reports_path, "jtl-#{timestamp}.zip")
        FileUtils.safe_unlink zip_file_path
        Zip::File.open(zip_file_path, Zip::File::CREATE) do |zf|
          data.each do |ex|
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
      current_project.execution_cycles.each(&:destroy)
      logger.info 'Purged all data for tests'
    when :clusters
      current_project.purge_clusters
      logger.info 'Purged all clusters'
    else
      current_project.destroy
      logger.info 'Purged all project data'
    end
  end

  def show(*args)
    what = (args.first || 'active').to_sym
    all = args[1].to_s.to_sym == :all || what == :all
    show_jmeter_plans(!all) if %i[jmeter active all].include?(what)
    show_load_agents(!all)  if %i[cluster active all].include?(what)
    show_target_hosts(!all) if %i[monitor active all].include?(what)
  end

  def status(*args)
    format, = args
    if current_project.current_execution_cycle
      running_agents = current_project.check_status
      if !running_agents.empty?
        logger.info 'Load generation running on following load agents:'
        text_table = Terminal::Table.new
        text_table.headings = %w[Cluster Agent PID]
        text_table.rows = running_agents.collect { |agent|
          [agent.clusterable.slug, agent.public_ip_address, agent.jmeter_pid]
        }

        if format && (format.to_sym == :json)
          puts running_agents.to_json
        else
          puts text_table.to_s
        end

      else
        logger.info 'Load generation finished on all load agents'
        if format && (format.to_sym == :json)
          puts [].to_json
        end
      end
    else
      logger.info 'No tests have been started'
    end
  end

  def show_jmeter_plans(only_active = true)
    jmeter_plans = []
    q = current_project.jmeter_plans
    q = q.active if only_active
    q.each do |jmeter_plan|
      plan = OpenStruct.new
      plan.name = jmeter_plan.test_plan_name
      plan.properties = jmeter_plan.properties_map
      jmeter_plans.push(plan)
    end
    render_view('jmeter_plan', jmeter_plans: jmeter_plans, only_active: only_active)
  end

  def show_load_agents(only_active = true)
    clustered_load_agents = []
    current_project.clusters.each do |cluster|
      cluster.clusterables(all = !only_active).each do |clusterable|
        view_item = OpenStruct.new
        view_item.clusterable_slug = clusterable.slug
        view_item.cluster_code = cluster.cluster_code
        view_item.terminal_table = Terminal::Table.new
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
    render_view('cluster', clustered_load_agents: clustered_load_agents, only_active: only_active)
  end

  def show_target_hosts(only_active = true)
    terminal_table = Terminal::Table.new
    terminal_table.headings = %w[Role Host Monitor PID]
    q = current_project.target_hosts
    q = q.active if only_active
    target_hosts = q.natural_order
    target_hosts.each do |target_host|
      terminal_table.add_row([
                               target_host.role_name,
                               target_host.host_name,
                               target_host.class.name.demodulize.tableize.singularize,
                               target_host.executable_pid
                             ])
    end
    render_view('monitor', terminal_table: terminal_table, only_active: only_active)
  end

  def render_view(template_file, context_vars = {})
    template_path = File.join(Hailstorm.templates_path, 'cli')
    template_file_path = File.join(template_path, template_file)

    engine = ActionView::Base.new
    engine.view_paths.push(template_path)
    engine.assign(context_vars)
    puts engine.render(file: template_file_path, formats: [:text], handlers: [:erb])
  end
end
