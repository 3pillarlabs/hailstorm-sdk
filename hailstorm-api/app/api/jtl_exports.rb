require 'sinatra'
require 'json'
require 'hailstorm/model/project'

post '/projects/:project_id/jtl_exports' do |project_id|
  project = Hailstorm::Model::Project.find(project_id)

  request.body.rewind
  # @type [Array]
  params = JSON.parse(request.body.read).sort_by(&:to_i)
  data = project.results(:export, cycle_ids: params, format: :zip, config: nil)
  JSON.dump(data)
end
