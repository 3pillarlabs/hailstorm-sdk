require 'digest'
require 'hailstorm/model/project'
require 'hailstorm/model/execution_cycle'
require 'model/project_configuration'

module ProjectsHelper

  MAX_PROJECT_CODE_LEN = 40

  # @param [Array<Hailstorm::Model::Project>] projects
  # @return [Array<Hailstorm::Model::Project>]
  def list_projects(projects)
    project_attrs_list = projects.map(&method(:project_attributes))
    run_before, never_run = project_attrs_list.partition do |attrs|
      attrs.key?(:current_execution_cycle) || attrs.key?(:last_execution_cycle)
    end

    run_before.sort do |a,b|
      b_ex_cycle = b[:current_execution_cycle] || b[:last_execution_cycle]
      a_ex_cycle = a[:current_execution_cycle] || a[:last_execution_cycle]
      b_ex_cycle[:started_at] <=> a_ex_cycle[:started_at]
    end + never_run
  end

  def project_attributes(project)
    project_attrs = project.attributes.symbolize_keys.slice(:title)
    project_attrs[:id] = project.id
    project_attrs[:code] = project.project_code
    if project.current_execution_cycle
      project_attrs[:running] = true
      project_attrs[:current_execution_cycle] = project.current_execution_cycle
                                                       .attributes
                                                       .symbolize_keys
                                                       .except(:started_at, :stopped_at)

      project_attrs[:current_execution_cycle][:id] = project.current_execution_cycle.id
      project_attrs[:current_execution_cycle].merge!(
        started_at: project.current_execution_cycle.started_at.to_i * 1000
      )
    end

    last_execution_cycle = project.execution_cycles
                                  .where.not(status: Hailstorm::Model::ExecutionCycle::States::STARTED)
                                  .order(stopped_at: :desc)
                                  .limit(1)
                                  .first
    if last_execution_cycle
      project_attrs[:last_execution_cycle] = last_execution_cycle.attributes
                                                                 .symbolize_keys
                                                                 .except(:started_at, :stopped_at)

      project_attrs[:last_execution_cycle][:id] = last_execution_cycle.id
      project_attrs[:last_execution_cycle].merge!(
        started_at: last_execution_cycle.started_at.to_i * 1000
      )

      if last_execution_cycle.status.to_sym == Hailstorm::Model::ExecutionCycle::States::STOPPED
        project_attrs[:last_execution_cycle].merge!(
          response_time: last_execution_cycle.avg_90_percentile,
          throughput: last_execution_cycle.avg_tps
        )
      end

      if last_execution_cycle.stopped_at
        project_attrs[:last_execution_cycle].merge!(
          stopped_at: last_execution_cycle.stopped_at.to_i * 1000
        )
      end
    end

    if project.jmeter_plans.count > 0
      project_attrs[:auto_stop] = project.jmeter_plans.all.reduce(true) {|s, jp| s &&= !jp.loop_forever?}
    end

    project_config = ProjectConfiguration.where(project_id: project.id).first
    if project_config
      hailstorm_config = deep_decode(project_config.stringified_config)
      if hailstorm_config.jmeter.test_plans.size == 0 ||
          hailstorm_config.clusters.select { |e| e.active || e.active.nil? }.size == 0
        project_attrs[:incomplete] = true
      end
    else
      project_attrs[:incomplete] = true
    end

    project_attrs
  end

  # @param [String] title
  # @return [String]
  def project_code_from(title:)
    title.length < MAX_PROJECT_CODE_LEN ? title.to_s.downcase.gsub(/\s+/, '-') : Digest::SHA1.hexdigest(title)
  end
end
