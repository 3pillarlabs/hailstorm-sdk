require 'sinatra'
require 'json'
require 'db/seed'
require 'helpers/projects_helper'
require 'hailstorm/model/project'
require 'hailstorm/support/configuration'
require 'model/project_configuration'
require 'hailstorm/middleware/command_execution_template'

include ProjectsHelper

get '/projects' do
  list = list_projects(Hailstorm::Model::Project.all).map(&method(:deep_camelize_keys))
  JSON.dump(list)
end

get '/projects/:id' do |id|
  sleep 0.5
  found_project = Seed::DB[:projects].first# .find { |project| project[:id] == id.to_s.to_i }
  return not_found unless found_project

  found_project = found_project.clone
  current_execution_cycle = Seed::DB[:executionCycles].find { |x| x[:projectId] == id && x[:stoppedAt].nil? }
  if current_execution_cycle
    found_project[:currentExecutionCycle] = current_execution_cycle.clone
    found_project[:currentExecutionCycle][:startedAt] = found_project[:currentExecutionCycle][:startedAt].to_i * 1000
  end

  JSON.dump(found_project)
end

patch '/projects/:id' do |id|
  key_identity = id.to_s.to_i
  found_project = Seed::DB[:projects].find { |project| project[:id] == key_identity }

  request.body.rewind
  # @type [Hash]
  data = JSON.parse(request.body.read)

  if found_project
    found_project[:title] = data['title'] if data.key?('title')
    found_project[:running] = data['running'] == 'true' if data.key?('running')
  end

  wait_duration = 0
  if data.key?('action')
    case data['action'].to_sym
    when :start
      wait_duration = 3
      Seed::DB[:executionCycles].push({
          id: Seed::DB[:sys][:execution_cycle_idx].call,
          startedAt: Time.now.to_i,
          threadsCount: 100,
          projectId: key_identity
      })

      found_project[:running] = true

    when :stop
      wait_duration = 3
      current_execution_cycle = Seed::DB[:executionCycles].find { |x| x[:projectId] == key_identity && x[:stoppedAt].nil? }
      raise(ArgumentError("No running execution cycle found for project_id: #{id}")) unless current_execution_cycle

      current_execution_cycle[:stoppedAt] = Time.now.to_i
      current_execution_cycle[:responseTime] = 234.56
      current_execution_cycle[:status] = Hailstorm::Model::ExecutionCycle::States::STOPPED
      current_execution_cycle[:throughput] = 10.24
      found_project[:running] = false

    when :abort
      wait_duration = 1.5
      current_execution_cycle = Seed::DB[:executionCycles].find { |x| x[:projectId] == key_identity && x[:stoppedAt].nil? }
      raise(ArgumentError("No running execution cycle found for project_id: #{id}")) unless current_execution_cycle

      current_execution_cycle[:stoppedAt] = Time.now.to_i
      current_execution_cycle[:status] = Hailstorm::Model::ExecutionCycle::States::ABORTED
      found_project[:running] = false

    when :terminate
      found_project = Hailstorm::Model::Project.find(id)
      project_config = ProjectConfiguration.where(project_id: found_project.id).first
      return not_found unless project_config

      hailstorm_config = deep_decode(project_config.stringified_config)
      cmd_template = Hailstorm::Middleware::CommandExecutionTemplate.new(found_project, hailstorm_config)
      cmd_template.terminate
    end
  end

  sleep(wait_duration) if wait_duration > 0
  204
end

post '/projects' do
  request.body.rewind
  # @type [Hash]
  data = JSON.parse(request.body.read)
  return 402 unless data.key?('title')

  project = Hailstorm::Model::Project.create!(
    project_code: project_code_from(title: data['title']),
    title: data['title']
  )

  project_attrs = project.attributes.symbolize_keys.except(:project_code).merge(
    id: project.id,
    running: false,
    incomplete: true,
    code: project.project_code
  )

  JSON.dump(deep_camelize_keys(project_attrs))
end

delete '/projects/:id' do |id|
  sleep 0.3
  Seed::DB[:projects].reject! { |project| project[:id] == id.to_s.to_i }
  204
end
