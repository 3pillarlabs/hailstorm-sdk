require 'sinatra'
require 'json'
require 'config/db/seed'

get '/projects/:project_id/jmeter_plans' do |project_id|
  sleep 0.3
  JSON.dump(Seed::DB[:jmeter_plans].select { |jp|  jp[:projectId] == project_id.to_s.to_i })
end

post '/projects/:project_id/jmeter_plans' do |project_id|
  sleep 0.3
  found_project = Seed::DB[:projects].find { |project| project[:id] == project_id.to_s.to_i }
  return not_found unless found_project

  request.body.rewind
  # @type [Hash]
  data = JSON.parse(request.body.read)
  jmeter_plan = {
      id: Seed::DB[:sys][:jmeter_plan_idx].call,
      name: data['name'],
      path: data['path'],
      projectId: found_project[:id]
  }

  jmeter_plan.merge!({properties: data['properties']}) if data['properties']
  jmeter_plan.merge!({dataFile: true}) if data['dataFile']
  Seed::DB[:jmeter_plans].push(jmeter_plan)
  found_project.delete(:incomplete)

  JSON.dump(jmeter_plan)
end

patch '/projects/:project_id/jmeter_plans/:id' do |project_id, id|
  sleep 0.3
  found_jmeter_plan = Seed::DB[:jmeter_plans].find { |jp| jp[:id] == id.to_i && jp[:projectId] == project_id.to_i }
  return not_found unless found_jmeter_plan

  request.body.rewind
  # @type [Hash]
  data = JSON.parse(request.body.read)
  found_jmeter_plan[:properties] = data['properties'] if data['properties']
  JSON.dump(found_jmeter_plan)
end

delete '/projects/:project_id/jmeter_plans/:id' do |project_id, id|
  sleep 0.3
  found_project = Seed::DB[:projects].find { |p| p[:id] == project_id.to_i }
  return not_found unless found_project

  Seed::DB[:jmeter_plans].reject! { |jp| jp[:id] == id.to_i && jp[:projectId] == found_project[:id] }
  found_project[:incomplete] = Seed::DB[:jmeter_plans].count { |jp| jp[:projectId] == found_project[:id] } == 0
  204
end