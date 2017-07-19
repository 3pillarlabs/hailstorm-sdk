json.array!(@target_hosts) do |target_host|
  json.extract! target_host, :id, :project_id, :host_name, :type, :role_name, :executable_path, :executable_pid, :user_name, :sampling_interval
  json.url target_host_url(target_host, format: :json)
end
