require 'sinatra'
require 'json'
require 'hailstorm/model/project'
require 'hailstorm/support/configuration'
require 'model/project_configuration'
require 'helpers/jmeter_helper'

include JMeterHelper

get '/projects/:project_id/jmeter_plans' do |project_id|
  project_config = ProjectConfiguration.where(project_id: project_id).first
  return JSON.dump([]) unless project_config

  # @type [Hailstorm::Support::Configuration]
  hailstorm_config = deep_decode(project_config.stringified_config)
  test_plans_attrs = (hailstorm_config.jmeter.test_plans || []).map { |e| { test_plan_name: e, jmx_file: true } }
  data_files_attrs = (hailstorm_config.jmeter.data_files || []).map { |e| { test_plan_name: e, jmx_file: false } }
  files_attrs = test_plans_attrs + data_files_attrs
  data_attrs = files_attrs.map { |partial_attrs| to_jmeter_attributes(hailstorm_config, project_id, partial_attrs) }
  JSON.dump(data_attrs)
end

post '/projects/:project_id/jmeter_plans' do |project_id|
  found_project = Hailstorm::Model::Project.find(project_id)
  request.body.rewind
  jmeter_plan = configure_jmeter(found_project, request)
  JSON.dump(jmeter_plan)
end

patch '/projects/:project_id/jmeter_plans/:id' do |project_id, id|
  project_config = ProjectConfiguration.where(project_id: project_id).first
  return not_found unless project_config

  request.body.rewind
  # @type [Hash]
  data = JSON.parse(request.body.read)
  hailstorm_config = deep_decode(project_config.stringified_config)
  test_plan_name = hailstorm_config.jmeter.test_plans.find { |e| e.to_java_string.hash_code == id.to_i }
  return not_found unless test_plan_name

  hailstorm_config.jmeter.properties(test_plan: test_plan_name) { |map| update_map(map, data) }
  project_config.update_attributes!(stringified_config: deep_encode(hailstorm_config))

  path, name = test_plan_name.split('/')
  JSON.dump(
    id: test_plan_name.to_java_string.hash_code,
    name: "#{name}.jmx",
    path: path,
    properties: hailstorm_config.jmeter.properties(test_plan: test_plan_name).entries
  )
end

delete '/projects/:project_id/jmeter_plans/:id' do |project_id, id|
  project_config = ProjectConfiguration.where(project_id: project_id).first
  return not_found unless project_config

  hailstorm_config = deep_decode(project_config.stringified_config)
  test_plan_name = hailstorm_config.jmeter.test_plans.find { |e| e.to_java_string.hash_code == id.to_i }
  hailstorm_config.jmeter.test_plans.reject! { |e| e == test_plan_name } if test_plan_name
  if hailstorm_config.jmeter.data_files
    data_file_name = hailstorm_config.jmeter.data_files.find { |e| e.to_java_string.hash_code == id.to_i }
    hailstorm_config.jmeter.data_files.reject! { |e| e == data_file_name } if data_file_name
  end

  project_config.update_attributes!(stringified_config: deep_encode(hailstorm_config))
  204
end
