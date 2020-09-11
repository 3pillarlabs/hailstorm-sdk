# frozen_string_literal: true

require 'hailstorm/cli'
require 'hailstorm/behavior/loggable'
require 'hailstorm/cli/view_template'

# CLI view renderer
class Hailstorm::Cli::ViewRenderer

  include Hailstorm::Behavior::Loggable

  attr_reader :project

  def initialize(new_project)
    @project = new_project
  end

  def render_default(*_args)
    puts view_template.render_load_agents(project.clusters)
    puts view_template.render_target_hosts(project.target_hosts.active.natural_order)
  end

  def render_setup(*_args)
    puts view_template.render_jmeter_plans(project.jmeter_plans.active)
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

  def render_show(query, show_active, what)
    should_show = ->(kind) { what == kind || %i[active all].include?(what) }
    puts view_template.render_jmeter_plans(query[:jmeter_plans], only_active: show_active) if should_show.call(:jmeter)
    puts view_template.render_load_agents(query[:clusters], only_active: show_active) if should_show.call(:cluster)
    puts view_template.render_target_hosts(query[:target_hosts], only_active: show_active) if should_show.call(:monitor)
  end

  def view_template
    @view_template ||= Hailstorm::Cli::ViewTemplate.new
  end
end
