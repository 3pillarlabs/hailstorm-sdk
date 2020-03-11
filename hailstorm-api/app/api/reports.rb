require 'sinatra'
require 'json'
require 'uri'
require 'hailstorm/model/project'
require 'model/project_configuration'

get '/projects/:project_id/reports' do |project_id|
  project = Hailstorm::Model::Project.find(project_id)
  reports = Hailstorm.fs
                     .fetch_reports(project.project_code)
                     .map { |attrs| attrs.merge(projectId: project.id) }

  JSON.dump(reports)
end

post '/projects/:project_id/reports' do |project_id|
  project = Hailstorm::Model::Project.find(project_id)
  project_config = ProjectConfiguration.find_by_project_id!(project.id)
  hailstorm_config = deep_decode(project_config.stringified_config)

  request.body.rewind
  data = JSON.parse(request.body.read).sort
  uri_path, id = project.results(:report, cycle_ids: data.map(&:to_i), config: hailstorm_config)
  uri = URI(uri_path)
  report = { id: id, projectId: project.id, title: File.basename(uri.path), uri: uri }
  JSON.dump(report)
end
