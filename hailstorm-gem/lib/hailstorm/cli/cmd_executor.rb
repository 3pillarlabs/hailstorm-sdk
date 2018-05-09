require 'hailstorm/cli'
require 'hailstorm/cli/help_doc'
require 'hailstorm/cli/view_renderer'
require 'hailstorm/middleware/command_execution_template'

# Command executor for CLI
class Hailstorm::Cli::CmdExecutor

  attr_reader :middleware
  attr_reader :project

  def initialize(new_middleware, new_project)
    @middleware = new_middleware
    @project = new_project
  end

  def interpret_execute(args)
    command_args = self.middleware.command_interpreter.interpret_command(*args).partition.with_index { |_e, i| i.zero? }
    method_name = command_args[0].first
    method_args = command_args[1]
    if method_name == :show
      show(*method_args)
    elsif method_name == :help
      help(*method_args)
    else
      execute_method_args(method_args, method_name)
    end
    method_name
  end

  def execute_method_args(method_args, method_name)
    values = command_execution_template.send(method_name, *method_args)
    render_method = "render_#{method_name}".to_sym
    render_args = values.is_a?(Array) ? values : [values]
    if view_renderer.respond_to?(render_method)
      view_renderer.send(render_method, *render_args)
    else
      view_renderer.render_default(*render_args)
    end
  end

  def show(*args)
    what = (args.first || 'active').to_sym
    show_all = args[1].to_s.to_sym == :all || what == :all
    q = query_relations_map(show_all)
    view_renderer.render_show(q, !show_all, what)
  end

  # r = show_all ? current_project.jmeter_plans : current_project.jmeter_plans.active
  def query_relations_map(show_all)
    q = %i[jmeter_plans clusters target_hosts].reduce({}) do |s, e|
      r = show_all ? project.send(e) : project.send(e).active
      s.merge(e => r)
    end
    q[:target_hosts] = q[:target_hosts].natural_order
    q
  end

  # Process the help command
  def help(help_on = :help)
    print help_doc.send("#{help_on}_options".to_sym)
  end

  def help_doc(help_docs_path = File.join(Hailstorm.templates_path, 'cli', 'help_docs.yml'))
    @help_doc ||= Hailstorm::Cli::HelpDoc.new(help_docs_path)
  end

  def command_execution_template
    @command_execution_template ||= Hailstorm::Middleware::CommandExecutionTemplate.new(project)
  end

  def view_renderer
    @view_renderer ||= Hailstorm::Cli::ViewRenderer.new(project)
  end
end
