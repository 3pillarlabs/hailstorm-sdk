require 'sinatra'
require 'json'
require 'config/db/seed'

get '/projects' do
  JSON.dump(Seed::DB[:projects].map { |project|
    project_with_execution_cycle = project.clone
    currentExecutionCycle = Seed::DB[:executionCycles].find { |x| x[:projectId] == project[:id] && x[:stoppedAt].nil? }
    unless currentExecutionCycle.nil?
      project_with_execution_cycle[:currentExecutionCycle] = currentExecutionCycle.clone
      project_with_execution_cycle[:currentExecutionCycle][:startedAt] =
          project_with_execution_cycle[:currentExecutionCycle][:startedAt].strftime('%Y-%m-%dT%H:%M:%S.%L%z')
    end

    unless project_with_execution_cycle[:lastExecutionCycle].nil?
      project_with_execution_cycle[:lastExecutionCycle] = project_with_execution_cycle[:lastExecutionCycle].clone
      project_with_execution_cycle[:lastExecutionCycle][:startedAt] =
          project_with_execution_cycle[:lastExecutionCycle][:startedAt].strftime('%Y-%m-%dT%H:%M:%S.%L%z')
      if project_with_execution_cycle[:lastExecutionCycle][:stoppedAt]
        project_with_execution_cycle[:lastExecutionCycle][:stoppedAt] =
            project_with_execution_cycle[:lastExecutionCycle][:stoppedAt].strftime('%Y-%m-%dT%H:%M:%S.%L%z')
      end
    end

    project_with_execution_cycle
  })
end

get '/projects/:id' do |id|
  found_project = Seed::DB[:projects].find { |project| project[:id] == id.to_s.to_i }
  found_project ? JSON.dump(found_project) : not_found
end
