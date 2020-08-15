require 'sinatra'
require 'json'
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
    if cluster_config.cluster_type == :amazon_cloud
      amazon_cloud_config(cluster_config, record_data)
    else
      data_center_config(cluster_config, record_data)
    end

    record_data[:title] = aws_cluster_title(cluster_config.region) if cluster_config.cluster_type == :amazon_cloud
    record_data[:id] = record_data[:title].to_java_string.hash_code
    cluster_config.cluster_code = "cluster-#{record_data[:id]}"
    record_data[:code] = cluster_config.cluster_code
  end

  record_data[:projectId] = found_project.id
  project_config.update!(stringified_config: deep_encode(hailstorm_config))
  JSON.dump(record_data)
end

get '/projects/:project_id/clusters' do |project_id|
  project = Hailstorm::Model::Project.find(project_id)
  project_config = ProjectConfiguration.where(project_id: project_id).first
  return not_found unless project_config

  # @type [Hailstorm::Support::Configuration] hailstorm_config
  hailstorm_config = deep_decode(project_config.stringified_config)
  JSON.dump(
    hailstorm_config.clusters
                    .map { |e| to_cluster_attributes(e, project: project).merge(projectId: project_id) }
                    .sort { |a, b| sort_clusters(a, b) }
  )
end

delete '/projects/:project_id/clusters/:id' do |project_id, id|
  found_project = Hailstorm::Model::Project.find(project_id)
  project_config = ProjectConfiguration.find_by_project_id!(found_project.id)

  # @type [Hailstorm::Support::Configuration] hailstorm_config
  hailstorm_config = deep_decode(project_config.stringified_config)
  matched_cluster_cfg = find_cluster_cfg(hailstorm_config, id)
  return 404 unless matched_cluster_cfg

  cluster = Hailstorm::Model::Cluster.where(project: found_project)
                                     .find_by_cluster_code(matched_cluster_cfg.cluster_code)
  if cluster
    clusterable = cluster.cluster_instance
    if clusterable.client_stats.count > 0 || clusterable.load_agents.count > 0
      matched_cluster_cfg.active = false
    else
      clusterable.destroy!
      cluster.destroy!
    end
  end

  if !cluster || matched_cluster_cfg.active.nil? || matched_cluster_cfg.active == true
    hailstorm_config.clusters.reject! do |cluster_cfg|
      id.to_i == compute_title_id(cluster_cfg)
    end
  end

  project_config.update!(stringified_config: deep_encode(hailstorm_config))
  204
end

patch '/projects/:project_id/clusters/:id' do |project_id, id|
  found_project = Hailstorm::Model::Project.find(project_id)
  project_config = ProjectConfiguration.find_by_project_id!(found_project.id)

  # @type [Hailstorm::Support::Configuration] hailstorm_config
  hailstorm_config = deep_decode(project_config.stringified_config)
  matched_cluster_cfg = find_cluster_cfg(hailstorm_config, id)
  return 404 unless matched_cluster_cfg

  request.body.rewind
  # @type [Hash]
  data = JSON.parse(request.body.read)
  data.each_pair { |key, value| matched_cluster_cfg.send("#{key}=", value) }
  project_config.update!(stringified_config: deep_encode(hailstorm_config))

  JSON.dump(
    to_cluster_attributes(
      matched_cluster_cfg,
      project: found_project
    ).merge(project_id: found_project.id)
  )
end
