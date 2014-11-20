json.array!(@clusters) do |cluster|
  json.extract! cluster, :id, :project_id, :name, :access_key, :secret_key, :ssh_identity, :region, :instance_type
  json.url cluster_url(cluster, format: :json)
end
