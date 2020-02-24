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
  found_project = Hailstorm::Model::Project.find(id)
  JSON.dump(deep_camelize_keys(project_attributes(found_project)))
end

patch '/projects/:id' do |id|
  found_project = Hailstorm::Model::Project.find(id)

  request.body.rewind
  # @type [Hash]
  data = JSON.parse(request.body.read)

  if data.key?('title')
    return 422 if data['title'].blank?
    found_project.update_column(:title, data['title'])
  end

  if data.key?('action')
    project_config = ProjectConfiguration.find_by_project_id(found_project.id)
    return 422 unless project_config

    # @type [Hailstorm::Support::Configuration] hailstorm_config
    hailstorm_config = deep_decode(project_config.stringified_config)
    cmd_template = Hailstorm::Middleware::CommandExecutionTemplate.new(found_project, hailstorm_config)

    case data['action'].to_sym
    when :start
      digest = Digest::SHA1.new
      digest.update(project_config.stringified_config)
      current_serial_version = digest.hexdigest
      if found_project.serial_version.nil? || found_project.serial_version != current_serial_version
        found_project.settings_modified = true
        found_project.update_attribute(:serial_version, current_serial_version)
      end

      cmd_template.start('redeploy')

    when :stop
      cmd_template.stop

    when :abort
      cmd_template.abort

    when :terminate
      cmd_template.terminate

    else
      return 422
    end
  end

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
