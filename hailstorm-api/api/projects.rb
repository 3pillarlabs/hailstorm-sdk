require 'sinatra'
require 'json'
require 'config/db/seed'

get '/projects' do
  sleep 0.3
  JSON.dump(Seed::DB[:projects].map {
      # @type [Hash] project
      |project|

    response_data = project.clone
    current_execution_cycle = Seed::DB[:executionCycles].find { |x| x[:projectId] == project[:id] && x[:stoppedAt].nil? }
    unless current_execution_cycle.nil?
      response_data[:currentExecutionCycle] = current_execution_cycle.clone
      response_data[:currentExecutionCycle][:startedAt] =
          response_data[:currentExecutionCycle][:startedAt].to_i * 1000
    end

    last_execution_cycle = Seed::DB[:executionCycles]
                               .select { |x| x[:projectId] == project[:id] && x[:stoppedAt] }
                               .sort { |a, b| b[:stoppedAt].to_i <=> a[:stoppedAt].to_i }
                               .first
    if last_execution_cycle
      response_data[:lastExecutionCycle] = last_execution_cycle.clone
      response_data[:lastExecutionCycle][:startedAt] = last_execution_cycle[:startedAt].to_i * 1000
      response_data[:lastExecutionCycle][:stoppedAt] = last_execution_cycle[:stoppedAt].to_i * 1000
    end

    response_data
  })
end

get '/projects/:id' do |id|
  sleep 0.5
  found_project = Seed::DB[:projects].find { |project| project[:id] == id.to_s.to_i }
  return not_found unless found_project

  found_project = found_project.clone
  current_execution_cycle = Seed::DB[:executionCycles].find { |x| x[:projectId] == id && x[:stoppedAt].nil? }
  if current_execution_cycle
    found_project[:currentExecutionCycle] = current_execution_cycle.clone
    found_project[:currentExecutionCycle][:startedAt] = found_project[:currentExecutionCycle][:startedAt].to_i * 1000
  end

  JSON.dump(found_project)
end

patch '/projects/:id' do |id|
  key_identity = id.to_s.to_i
  sleep 0.1
  found_project = Seed::DB[:projects].find { |project| project[:id] == key_identity }
  return not_found unless found_project

  request.body.rewind
  # @type [Hash]
  data = JSON.parse(request.body.read)
  found_project[:title] = data['title'] if data.key?('title')
  found_project[:running] = data['running'] == 'true' if data.key?('running')
  wait_duration = 0
  if data.key?('action')
    case data['action'].to_sym
    when :start
      wait_duration = 3
      Seed::DB[:executionCycles].push({
          id: Seed::DB[:sys][:execution_cycle_idx].call,
          startedAt: Time.now.to_i,
          threadsCount: 100,
          projectId: key_identity
      })

      found_project[:running] = true

    when :stop
      wait_duration = 3
      current_execution_cycle = Seed::DB[:executionCycles].find { |x| x[:projectId] == key_identity && x[:stoppedAt].nil? }
      raise(ArgumentError("No running execution cycle found for project_id: #{id}")) unless current_execution_cycle

      current_execution_cycle[:stoppedAt] = Time.now.to_i
      current_execution_cycle[:responseTime] = 234.56
      current_execution_cycle[:status] = Hailstorm::Model::ExecutionCycle::States::STOPPED
      current_execution_cycle[:throughput] = 10.24
      found_project[:running] = false

    when :abort, :terminated
      wait_duration = 1.5
      current_execution_cycle = Seed::DB[:executionCycles].find { |x| x[:projectId] == key_identity && x[:stoppedAt].nil? }
      raise(ArgumentError("No running execution cycle found for project_id: #{id}")) unless current_execution_cycle

      current_execution_cycle[:stoppedAt] = Time.now.to_i
      current_execution_cycle[:status] = Hailstorm::Model::ExecutionCycle::States::ABORTED
      found_project[:running] = false
    end
  end

  sleep(wait_duration) if wait_duration > 0
  204
end

post '/projects' do
  sleep 0.1
  request.body.rewind
  # @type [Hash]
  data = JSON.parse(request.body.read)
  return 402 unless data.key?('title')

  project = {
      id: Seed::DB[:sys][:project_idx].call,
      autoStop: false,
      code: data['title'].to_s.downcase.gsub(/\s+/, '-'),
      title: data['title'],
      running: false,
      incomplete: true
  }

  Seed::DB[:projects].push(project)
  JSON.dump(project)
end

delete '/projects/:id' do |id|
  sleep 0.3
  Seed::DB[:projects].reject! { |project| project[:id] == id.to_s.to_i }
  204
end