require 'terminal-table'
require 'hailstorm/cli'

# CLI View template
class Hailstorm::Cli::ViewTemplate

  # @param [Enumerable<Hailstorm::Model::JMeter>] enumerable
  def render_jmeter_plans(enumerable, only_active = true)
    jmeter_plans = []
    enumerable.each do |jmeter_plan|
      plan = OpenStruct.new
      plan.name = jmeter_plan.test_plan_name
      plan.properties = jmeter_plan.properties_map
      jmeter_plans.push(plan)
    end
    render_view('jmeter_plan', jmeter_plans: jmeter_plans, only_active: only_active)
  end

  # @param [Enumerable<Hailstorm::Model::Cluster>] enumerable
  def render_load_agents(enumerable, only_active = true)
    clustered_load_agents = []
    enumerable.each do |cluster|
      clustered_load_agents.push(clusterable_to_view_model(cluster, only_active))
    end
    render_view('cluster', clustered_load_agents: clustered_load_agents, only_active: only_active)
  end

  # @param [Enumerable<Hailstorm::Model::TargetHost>] enumerable
  def render_target_hosts(enumerable, only_active = true)
    terminal_table = Terminal::Table.new
    terminal_table.headings = %w[Role Host Monitor PID]
    enumerable.each do |target_host|
      row = [
        target_host.role_name,
        target_host.host_name,
        target_host.class.name.demodulize.tableize.singularize,
        target_host.executable_pid
      ]
      terminal_table.add_row(row)
    end
    render_view('monitor', terminal_table: terminal_table, only_active: only_active)
  end

  def render_view(template_file, context_vars = {})
    template_path = File.join(Hailstorm.templates_path, 'cli')
    template_file_path = File.join(template_path, template_file)

    engine = ActionView::Base.new
    engine.view_paths.push(template_path)
    engine.assign(context_vars)
    engine.render(file: template_file_path, formats: [:text], handlers: [:erb])
  end

  def render_results_show(data, format = nil)
    if format.nil?
      text_table = Terminal::Table.new
      text_table.headings = ['TEST', 'Threads', '90 %tile', 'TPS', 'Started', 'Stopped']
      text_table.rows = data.collect { |execution_cycle| exec_cycle_to_attrs(execution_cycle).values }

      text_table.to_s
    else
      list = data.reduce([]) { |acc, execution_cycle| acc.push(exec_cycle_to_attrs(execution_cycle)) }
      list.to_json
    end
  end

  def render_running_agents(agents, format = nil)
    if format.to_s.to_sym == :json
      agents.reduce([]) { |acc, ag| acc.push(ag.to_json) }.to_json
    else
      text_table = Terminal::Table.new
      text_table.headings = %w[Cluster Agent PID]
      text_table.rows = agents.collect { |agent| [agent.clusterable.slug, agent.public_ip_address, agent.jmeter_pid] }
      text_table.to_s
    end
  end

  private

  def exec_cycle_to_attrs(execution_cycle)
    {
      execution_cycle_id: execution_cycle.id,
      total_threads_count: execution_cycle.total_threads_count,
      avg_90_percentile: execution_cycle.avg_90_percentile,
      avg_tps: execution_cycle.avg_tps.round(2),
      started_at: execution_cycle.formatted_started_at,
      stopped_at: execution_cycle.formatted_stopped_at
    }
  end

  def clusterable_to_view_model(cluster, only_active)
    clusterable = cluster.cluster_instance
    view_item = OpenStruct.new
    view_item.clusterable_slug = clusterable.slug
    view_item.cluster_code = cluster.cluster_code
    view_item.terminal_table = Terminal::Table.new
    view_item.terminal_table.headings = ['JMeter Plan', 'Type', 'IP Address', 'JMeter PID']
    q = clusterable.load_agents
    q = q.active if only_active
    q.each do |load_agent|
      row = load_agent_values(load_agent)
      view_item.terminal_table.add_row(row)
    end
    view_item
  end

  def load_agent_values(load_agent)
    [
      load_agent.jmeter_plan.test_plan_name,
      (load_agent.master? ? 'Master' : 'Slave'),
      load_agent.public_ip_address,
      load_agent.jmeter_pid
    ]
  end

end
