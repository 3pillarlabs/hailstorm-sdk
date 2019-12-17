require 'sinatra'
require 'json'
require 'config/db/seed'

get '/projects' do
  JSON.dump(Seed::DB[:projects].map {
      # @type [Hash] project
      |project|

    project_with_execution_cycle = project.clone
    current_execution_cycle = Seed::DB[:executionCycles].find { |x| x[:projectId] == project[:id] && x[:stoppedAt].nil? }
    unless current_execution_cycle.nil?
      project_with_execution_cycle[:currentExecutionCycle] = current_execution_cycle.clone
      project_with_execution_cycle[:currentExecutionCycle][:startedAt] =
          project_with_execution_cycle[:currentExecutionCycle][:startedAt].to_i * 1000
    end

    unless project_with_execution_cycle[:lastExecutionCycle].nil?
      project_with_execution_cycle[:lastExecutionCycle] = project_with_execution_cycle[:lastExecutionCycle].clone
      project_with_execution_cycle[:lastExecutionCycle][:startedAt] =
          project_with_execution_cycle[:lastExecutionCycle][:startedAt].to_i * 1000
      if project_with_execution_cycle[:lastExecutionCycle][:stoppedAt]
        project_with_execution_cycle[:lastExecutionCycle][:stoppedAt] =
            project_with_execution_cycle[:lastExecutionCycle][:stoppedAt].to_i * 1000
      end
    end

    project_with_execution_cycle
  })
end

get '/projects/:id' do |id|
  found_project = Seed::DB[:projects].find { |project| project[:id] == id.to_s.to_i }
  found_project ? JSON.dump(found_project) : not_found
end
