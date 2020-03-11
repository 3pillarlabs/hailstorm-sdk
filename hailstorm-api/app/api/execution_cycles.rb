require 'sinatra'
require 'json'
require 'hailstorm/model/project'
require 'hailstorm/model/execution_cycle'
require 'helpers/execution_cycles_helper'

include ExecutionCyclesHelper

get '/projects/:project_id/execution_cycles' do |project_id|
  project = Hailstorm::Model::Project.find(project_id)
  execution_cycles_attrs = project.execution_cycles
                                  .where.not(status: Hailstorm::Model::ExecutionCycle::States::ABORTED)
                                  .where.not(status: Hailstorm::Model::ExecutionCycle::States::TERMINATED)
                                  .order(started_at: :desc)
                                  .map(&method(:execution_cycle_attributes))
                                  .map(&method(:deep_camelize_keys))

  JSON.dump(execution_cycles_attrs)
end

patch '/projects/:project_id/execution_cycles/:id' do |project_id, id|
  found_x_cycle = Hailstorm::Model::ExecutionCycle.where(project_id: project_id).find(id)

  request.body.rewind
  # @type [Hash]
  data = JSON.parse(request.body.read)
  if data['status']
    case data['status']
    when Hailstorm::Model::ExecutionCycle::States::EXCLUDED.to_s
      found_x_cycle.excluded!
    when Hailstorm::Model::ExecutionCycle::States::STOPPED.to_s
      found_x_cycle.stopped!
    else
      return 422
    end
  end

  JSON.dump(deep_camelize_keys(execution_cycle_attributes(found_x_cycle.reload)))
end

get '/projects/:project_id/execution_cycles/current' do |project_id|
  project = Hailstorm::Model::Project.find(project_id)
  current_cycle = project.current_execution_cycle
  return not_found unless current_cycle

  running_agents = project.check_status
  JSON.dump(deep_camelize_keys(current_cycle.attributes.merge(
                                 id: current_cycle.id,
                                 started_at: current_cycle.started_at.to_i * 1000,
                                 noRunningTests: running_agents.empty?
                               )))
end
