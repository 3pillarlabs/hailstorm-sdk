require 'sinatra'
require 'json'
require 'config/db/seed'

get '/projects' do
  JSON.dump(Seed::DB[:projects].map { |project|
    project_with_execution_cycle = project.clone
    project_with_execution_cycle[:currentExecutionCycle] = Seed::DB[:executionCycles]
                                          .find { |x| x[:projectId] == project[:id] && x[:stoppedAt].nil? }
    project_with_execution_cycle
  })
end

get '/projects/:id' do |id|
  found_project = Seed::DB[:projects].select { |project| project[:id] == id.to_s.to_i }.first
  found_project ? JSON.dump(found_project) : not_found
end
