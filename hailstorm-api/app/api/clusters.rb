require 'sinatra'
require 'json'
require 'db/seed'
require 'helpers/clusters_helper'
require 'hailstorm/support/configuration'
require 'hailstorm/model/project'
require 'model/project_configuration'

include ClustersHelper

post '/projects/:project_id/clusters' do |project_id|
  # @type [Hailstorm::Model::Project]
  found_project = Hailstorm::Model::Project.find(project_id)

  request.body.rewind
  data = JSON.parse(request.body.read)
  record_data = Hash[data].symbolize_keys
  project_config = ProjectConfiguration.where(project_id: found_project.id)
                                       .first_or_create!(
                                         stringified_config: deep_encode(Hailstorm::Support::Configuration.new)
                                       )

  hailstorm_config = deep_decode(project_config.stringified_config)
  hailstorm_config.clusters(api_to_config_cluster_type(record_data[:type])) do |cluster_config|
    cluster_config.cluster_type == :amazon_cloud ? amazon_cloud_config(cluster_config, record_data) :
                                                   data_center_config(cluster_config, record_data)

    record_data[:title] = aws_cluster_title(cluster_config.region) if cluster_config.cluster_type == :amazon_cloud
    record_data[:id] = record_data[:title].to_java_string.hash_code
    cluster_config.cluster_code = "cluster-#{record_data[:id]}"
    record_data[:code] = cluster_config.cluster_code
  end

  record_data[:projectId] = found_project.id
  project_config.update_attributes!(stringified_config: deep_encode(hailstorm_config))
  logger.debug { project_config.stringified_config }
  JSON.dump(record_data)
end

get '/projects/:project_id/clusters' do |project_id|
  project_config = ProjectConfiguration.where(project_id: project_id).first
  return not_found unless project_config

  # @type [Hailstorm::Support::Configuration] hailstorm_config
  hailstorm_config = deep_decode(project_config.stringified_config)
  JSON.dump(hailstorm_config.clusters.map { |e| to_cluster_attributes(e).merge(projectId: project_id) }
                                     .map { |e| e.merge(code: "cluster-#{e[:id]}") })
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
