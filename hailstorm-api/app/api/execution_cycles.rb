require 'sinatra'
require 'json'
require 'db/seed'
require 'hailstorm/model/project'
require 'hailstorm/model/execution_cycle'

get '/projects/:project_id/execution_cycles' do |project_id|
  project = Hailstorm::Model::Project.find(project_id)
  execution_cycles_attrs = project.execution_cycles
                               .where.not(status: Hailstorm::Model::ExecutionCycle::States::ABORTED)
                               .order(started_at: :desc)
                               .map {|ex| ex.attributes
                                              .merge(
                                                id: ex.id,
                                                started_at: ex.started_at.to_i * 1000,
                                                response_time: ex.avg_90_percentile,
                                                throughput: ex.avg_tps
                                              )
                                              .merge(ex.stopped_at ? {stopped_at: ex.stopped_at.to_i * 1000} : {})
                               }
                               .map(&method(:deep_camelize_keys))

  JSON.dump(execution_cycles_attrs)
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

get '/projects/:project_id/execution_cycles/current' do |project_id|
  project = Hailstorm::Model::Project.find(project_id)
  current_cycle = project.current_execution_cycle
  return not_found unless current_cycle

  begin
    running_agents = project.check_status
    JSON.dump(deep_camelize_keys(current_cycle.attributes.merge(
      id: current_cycle.id,
      started_at: current_cycle.started_at.to_i * 1000,
      noRunningTests: running_agents.empty?
    )))

  rescue StandardError => error
    logger.error(error.message)
    500
  end
end
