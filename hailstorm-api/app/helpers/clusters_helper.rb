require 'hailstorm/model/amazon_cloud'

module ClustersHelper

  # @param [Hailstorm::Support::Configuration::ClusterBase] cluster
  # @return [Hash]
  def to_cluster_attributes(cluster)
    case cluster.cluster_type
    when :amazon_cloud
      # @type [Hailstorm::Support::Configuration::AmazonCloud] amz
      amz = cluster
      title = aws_cluster_title(amz.region)
      {
        type: 'AWS',
        title: title,
        id: title.to_java_string.hash_code,
        accessKey: amz.access_key,
        secretKey: amz.secret_key,
        instanceType: amz.instance_type,
        maxThreadsByInstance: amz.max_threads_per_agent,
        region: amz.region
      }
    when :data_center
      # @type [Hailstorm::Support::Configuration::DataCenter] dc
      dc = cluster
      {
        type: 'DataCenter',
        title: dc.title,
        id: dc.title.to_java_string.hash_code,
        userName: dc.user_name,
        sshIdentity: { name: File.basename(dc.ssh_identity), path: File.dirname(dc.ssh_identity) },
        machines: dc.machines,
        port: dc.ssh_port
      }
    else
      {}
    end
  end

  # @param [String] api_cluster_type
  # @return [Symbol]
  def api_to_config_cluster_type(api_cluster_type)
    case api_cluster_type
    when 'AWS'
      :amazon_cloud
    when 'DataCenter'
      :data_center
    else
      raise StandardError, "unknown api_cluster_type #{api_cluster_type}"
    end
  end

  # @param [Hailstorm::Support::Configuration::ClusterBase] cluster_config
  # @param [Hash] api_params
  def amazon_cloud_config(cluster_config, api_params)
    # @type [Hailstorm::Support::Configuration::AmazonCloud] amz
    amz = cluster_config
    amz.access_key = api_params[:accessKey]
    amz.secret_key = api_params[:secretKey]
    amz.instance_type = api_params[:instanceType].presence
    amz.max_threads_per_agent = api_params[:maxThreadsByInstance] if api_params[:maxThreadsByInstance]
    amz.region = api_params[:region].presence
    amz
  end

  # @param [Hailstorm::Support::Configuration::ClusterBase] cluster_config
  # @param [Hash] api_params
  def data_center_config(cluster_config, api_params)
    # @type [Hailstorm::Support::Configuration::DataCenter] dc
    dc = cluster_config
    dc.title = api_params[:title]
    dc.user_name = api_params[:userName]
    dc.ssh_identity = "#{api_params[:sshIdentity]['path']}/#{api_params[:sshIdentity]['name']}"
    dc.machines = api_params[:machines]
    dc.ssh_port = api_params[:port] if api_params[:port].presence
    dc
  end

  # @param [String] region
  # @return [String]
  def aws_cluster_title(region)
    "AWS #{region}"
  end
end
