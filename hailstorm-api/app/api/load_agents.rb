# frozen_string_literal: true

require 'sinatra'
require 'json'

require 'hailstorm/model/project'

get '/projects/:project_id/load_agents' do |project_id|
  found_project = Hailstorm::Model::Project.find(project_id)
  load_agents = found_project.jmeter_plans.all.flat_map(&:load_agents)
  JSON.dump(load_agents)
end
