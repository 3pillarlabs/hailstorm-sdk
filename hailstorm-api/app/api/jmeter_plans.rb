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
  JSON.dump(
    (
      (hailstorm_config.jmeter.test_plans || []).map { |e| {test_plan_name: e, jmx_file: true} } +
      (hailstorm_config.jmeter.data_files || []).map { |e| {test_plan_name: e, jmx_file: false} }
    )
      .map { |partial_attrs| to_jmeter_attributes(hailstorm_config, project_id, partial_attrs) }
  )
end

post '/projects/:project_id/jmeter_plans' do |project_id|
  found_project = Hailstorm::Model::Project.find(project_id)

  request.body.rewind
  # @type [Hash]
  data = JSON.parse(request.body.read)
  project_config = ProjectConfiguration
                     .where(project_id: found_project.id)
                     .first_or_create!(stringified_config: deep_encode(Hailstorm::Support::Configuration.new))

  logger.debug { project_config.stringified_config }
  hailstorm_config = deep_decode(project_config.stringified_config)
  test_plan_name = "#{data['path']}/#{data['name']}"
  file_id = nil
  if jmx_file?(test_plan_name)
    file_id = File.strip_ext(test_plan_name).to_java_string.hash_code
    hailstorm_config.jmeter do |jmeter|
      jmeter.add_test_plan(test_plan_name)
      if data['properties']
        jmeter.properties(test_plan: test_plan_name) { |map| update_map(map, data) }
      end
    end
  else
    file_id = test_plan_name.to_java_string.hash_code
    hailstorm_config.jmeter.data_files.push(test_plan_name)
  end

  project_config.update_attributes!(stringified_config: deep_encode(hailstorm_config))

  jmeter_plan = {
    id: file_id,
    name: data['name'],
    path: data['path'],
    projectId: found_project.id
  }

  jmeter_plan.merge!({properties: data['properties']}) if data['properties']
  jmeter_plan.merge!({dataFile: true}) if data['dataFile']

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
  JSON.dump({
    id: test_plan_name.to_java_string.hash_code,
    name: "#{name}.jmx",
    path: path,
    properties: hailstorm_config.jmeter.properties(test_plan: test_plan_name).entries
  })
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
