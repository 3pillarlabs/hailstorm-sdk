require 'sinatra'
require 'json'
require 'db/seed'

get '/projects/:id/execution_cycles' do |project_id|
  sleep 0.3
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

patch '/projects/:projectId/execution_cycles/:id' do |projectId, id|
  sleep 0.3
  found_x_cycle = Seed::DB[:executionCycles].find { |x| x[:id] == id.to_s.to_i && x[:projectId] == projectId.to_s.to_i }
  return not_found unless found_x_cycle

  request.body.rewind
  # @type [Hash]
  data = JSON.parse(request.body.read)
  found_x_cycle[:status] = data['status'] if data['status']
  response_data = found_x_cycle.clone
  response_data[:startedAt] = response_data[:startedAt].to_i * 1000
  response_data[:stoppedAt] = response_data[:stoppedAt].to_i * 1000 if response_data[:stoppedAt]
  JSON.dump(response_data)
end
