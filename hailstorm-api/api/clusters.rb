require 'sinatra'
require 'json'
require 'config/db/seed'

post '/projects/:project_id/clusters' do |project_id|
  sleep 0.3
  # @type [Hash]
  found_project = Seed::DB[:projects].find { |p| p[:id] == project_id.to_i }
  return not_found unless found_project

  request.body.rewind
  data = JSON.parse(request.body.read)
  record_data = Hash[data].symbolize_keys
  record_data[:id] = Seed::DB[:sys][:cluster_idx].call
  record_data[:title] = "AWS #{data['region']}" if data['type'] == 'AWS'
  record_data[:code] = "cluster-#{record_data[:id]}"
  record_data[:projectId] = found_project[:id]

  Seed::DB[:clusters].push(record_data.slice(:id, :title, :type, :code, :projectId))
  polymorphic_table = record_data[:type] == 'AWS' ? :amazon_clouds : :data_centers
  Seed::DB[polymorphic_table].push(record_data.except(:title, :type, :code, :projectId))
  found_project.delete(:incomplete)

  JSON.dump(record_data)
end

get '/projects/:project_id/clusters' do |project_id|
  sleep 0.3
  found_project = Seed::DB[:projects].find { |p| p[:id] == project_id.to_i }
  return not_found unless found_project

  data = Seed::DB[:clusters]
    .select { |cl| cl[:projectId] == found_project[:id] }
    .map do |cl|
    if cl[:type] == 'AWS'
      cl.merge(Seed::DB[:amazon_clouds].find { |amz| amz[:id] == cl[:id] })
    elsif cl[:type] == 'DataCenter'
      cl.merge(Seed::DB[:data_centers].find { |dc| dc[:id] == cl[:id] })
    end
  end

  JSON.dump(data)
end

delete '/projects/:project_id/clusters/:id' do |project_id, id|
  sleep 0.3
  found_project = Seed::DB[:projects].find { |p| p[:id] == project_id.to_i }
  return not_found unless found_project

  found_cluster = Seed::DB[:clusters].find { |cl| cl[:id] == id.to_i && cl[:projectId] == found_project[:id] }
  return not_found unless found_cluster

  Seed::DB[:clusters].reject! { |cl| cl[:id] == found_cluster[:id] }
  polymorphic_table = found_cluster[:type] == 'AWS' ? :amazon_clouds : :data_centers
  Seed::DB[polymorphic_table].reject { |cl| cl[:id] == found_cluster[:id] }

  found_project[:incomplete] = Seed::DB[:clusters].count { |cl| cl[:projectId] == found_project[:id] } == 0
  204
end
