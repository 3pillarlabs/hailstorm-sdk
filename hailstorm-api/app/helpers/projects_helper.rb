require 'digest'
require 'hailstorm/model/project'
require 'hailstorm/model/execution_cycle'
require 'model/project_configuration'
require 'helpers/execution_cycles_helper'
require 'hailstorm/model/amazon_cloud'
require 'hailstorm/model/data_center'
require 'hailstorm/model/load_agent'

# Helper for projects API
module ProjectsHelper
  include ExecutionCyclesHelper

  MAX_PROJECT_CODE_LEN = 40

  # @param [Array<Hailstorm::Model::Project>] projects
  # @return [Array<Hailstorm::Model::Project>]
  def list_projects(projects)
    project_attrs_list = projects.map(&method(:project_attributes))
    run_before, never_run = project_attrs_list.partition do |attrs|
      attrs.key?(:current_execution_cycle) || attrs.key?(:last_execution_cycle)
    end

    run_before.sort do |a, b|
      b_ex_cycle = b[:current_execution_cycle] || b[:last_execution_cycle]
      a_ex_cycle = a[:current_execution_cycle] || a[:last_execution_cycle]
      b_ex_cycle[:started_at] <=> a_ex_cycle[:started_at]
    end + never_run
  end

  def project_attributes(project)
    project_attrs = project.attributes.symbolize_keys.slice(:title)
    project_attrs[:id] = project.id
    project_attrs[:code] = project.project_code
    add_current_execution_cycle(project, project_attrs)
    add_last_execution_cycle(project, project_attrs)
    begin
      add_auto_stop_attribute(project, project_attrs)
    rescue StandardError => e
      logger.warn(e.message) if respond_to?(:logger)
    end

    add_incomplete_attribute(project, project_attrs)
    add_live_attribute(project, project_attrs)
    project_attrs
  end

  # @param [String] title
  # @return [String]
  def project_code_from(title:)
    title.length < MAX_PROJECT_CODE_LEN ? title.to_s.downcase.gsub(/\s+/, '-') : Digest::SHA1.hexdigest(title)
  end

  def process_action(cmd_template, data, found_project, project_config)
    case data['action'].to_sym
    when :start
      update_serial_version(found_project, project_config)
      cmd_template.start('redeploy')

    when :stop
      cmd_template.stop

    when :abort
      cmd_template.abort

    when :terminate
      cmd_template.terminate

    else
      raise(Hailstorm::UnknownCommandException, data['action'])
    end
  end

  private

  def add_incomplete_attribute(project, project_attrs)
    project_config = ProjectConfiguration.where(project_id: project.id).first
    if project_config
      hailstorm_config = deep_decode(project_config.stringified_config)
      if hailstorm_config.jmeter.test_plans.empty? ||
         hailstorm_config.clusters.select { |e| e.active || e.active.nil? }.empty?
        project_attrs[:incomplete] = true
      end
    else
      project_attrs[:incomplete] = true
    end
  end

  def add_auto_stop_attribute(project, project_attrs)
    return unless project.jmeter_plans.count > 0

    project_attrs[:auto_stop] = project.jmeter_plans.all.reduce(true) { |s, jp| s & !jp.loop_forever? }
  end

  def add_last_execution_cycle(project, project_attrs)
    last_execution_cycle = project.execution_cycles
                                  .where.not(status: Hailstorm::Model::ExecutionCycle::States::STARTED)
                                  .order(stopped_at: :desc)
                                  .limit(1)
                                  .first

    return unless last_execution_cycle

    project_attrs[:last_execution_cycle] = execution_cycle_attributes(last_execution_cycle)
  end

  def add_current_execution_cycle(project, project_attrs)
    current_execution_cycle = project.current_execution_cycle
    return unless current_execution_cycle

    project_attrs[:running] = true
    project_attrs[:current_execution_cycle] = execution_cycle_attributes(current_execution_cycle)
  end

  def update_serial_version(found_project, project_config)
    digest = Digest::SHA1.new
    digest.update(project_config.stringified_config)
    current_serial_version = digest.hexdigest
    return unless found_project.serial_version.nil? || found_project.serial_version != current_serial_version

    found_project.settings_modified = true
    found_project.update_attribute(:serial_version, current_serial_version)
  end

  # @param [Hailstorm::Model::Project] project
  # @param [Hash] project_attrs
  def add_live_attribute(project, project_attrs)
    project_clusters = project.clusters.all
    if project_clusters.size > 0 &&
       project_clusters.all? { |cluster| cluster.cluster_type == Hailstorm::Model::DataCenter.name }

      project_attrs.delete(:live)
      return
    end

    project_attrs[:live] = Hailstorm::Model::LoadAgent
                           .joins('JOIN amazon_clouds ON amazon_clouds.id = load_agents.clusterable_id')
                           .where(amazon_clouds: { project_id: project.id })
                           .where('load_agents.identifier IS NOT NULL')
                           .count('load_agents.id') > 0
  end
end
