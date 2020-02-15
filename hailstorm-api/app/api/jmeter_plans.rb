require 'sinatra'
require 'json'
require 'db/seed'
require 'hailstorm/model/project'
require 'hailstorm/support/configuration'
require 'model/project_configuration'
require 'helpers/jmeter_helper'

include JMeterHelper

get '/projects/:project_id/jmeter_plans' do |project_id|
  project_config = ProjectConfiguration.where(project_id: project_id).first
  return JSON.dump([]) unless project_config

  # @type [Hailstorm::Support::Configuration]
  hailstorm_config = Marshal.load(project_config.stringified_config)
  JSON.dump(
    (
      (hailstorm_config.jmeter.test_plans || []).map { |e| {test_plan_name: e, jmx_file: true} } +
      (hailstorm_config.jmeter.data_files || []).map { |e| {test_plan_name: e, jmx_file: false} }
    )
      .map
      .with_index { |partial_attrs, index| to_jmeter_attributes(hailstorm_config, project_id, partial_attrs, index) })
end

post '/projects/:project_id/jmeter_plans' do |project_id|
  found_project = Hailstorm::Model::Project.find(project_id)

  request.body.rewind
  # @type [Hash]
  data = JSON.parse(request.body.read)
  project_config = ProjectConfiguration
                     .where(project_id: found_project.id)
                     .first_or_create!(stringified_config: Marshal.dump(Hailstorm::Support::Configuration.new))

  hailstorm_config = Marshal.load(project_config.stringified_config)
  test_plan_name = "#{data['path']}/#{data['name']}"
  if jmx_file?(test_plan_name)
    hailstorm_config.jmeter do |jmeter|
      jmeter.add_test_plan(test_plan_name)
      if data['properties']
        jmeter.properties(test_plan: test_plan_name) { |map| update_map(map, data) }
      end
    end
  else
    hailstorm_config.jmeter.data_files.push(test_plan_name)
  end

  project_config.update_attributes!(stringified_config: Marshal.dump(hailstorm_config))

  jmeter_plan = {
    id: "#{found_project.id}#{hailstorm_config.jmeter.test_plans.size}",
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
  hailstorm_config = Marshal.load(project_config.stringified_config)
  matched_index = -1
  hailstorm_config.jmeter.test_plans.each_index do |index|
    matched_index = index if "#{project_id}#{index + 1}" == id.to_s
  end

  return not_found if matched_index < 0

  test_plan_name = hailstorm_config.jmeter.test_plans[matched_index]
  hailstorm_config.jmeter.properties(test_plan: test_plan_name) { |map| update_map(map, data) }
  JSON.dump({
    id: "#{project_id}#{matched_index + 1}",
    name: "#{File.basename(test_plan_name)}.jmx",
    path: File.dirname(test_plan_name),
    properties: hailstorm_config.jmeter.properties(test_plan: test_plan_name).entries
  })
end

delete '/projects/:project_id/jmeter_plans/:id' do |project_id, id|
  project_config = ProjectConfiguration.where(project_id: project_id).first
  return not_found unless project_config

  hailstorm_config = Marshal.load(project_config.stringified_config)
  matched_index = -1
  hailstorm_config.jmeter.test_plans.each_index do |index|
    matched_index = index if "#{project_id}#{index + 1}" == id.to_s
  end

  return not_found if matched_index < 0

  hailstorm_config.jmeter.test_plans = hailstorm_config.jmeter.test_plans.select.with_index { |_e, i| i != matched_index }
  project_config.update_attributes!(stringified_config: Marshal.dump(hailstorm_config))
  204
end
