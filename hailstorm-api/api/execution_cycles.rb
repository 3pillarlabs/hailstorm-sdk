require 'sinatra'
require 'json'
require 'config/db/seed'

get '/projects/:id/execution_cycles' do |project_id|
  found_project = Seed::DB[:projects].find { |project| project[:id] == project_id.to_s.to_i }
  return not_found unless found_project

  JSON.dump(
      Seed::DB[:executionCycles]
          .select { |x| x[:projectId] == project_id.to_s.to_i &&
              x[:status] != Hailstorm::Model::ExecutionCycle::States::ABORTED }
          .map(&:clone)
          .map do |x|
            x[:startedAt] = x[:startedAt].to_i * 1000
            x[:stoppedAt] = x[:stoppedAt].to_i * 1000 if x[:stoppedAt]
            x
          end
  )
end
