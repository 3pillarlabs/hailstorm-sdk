# frozen_string_literal: true

require 'hailstorm/model/amazon_cloud'

# Helper for Clusters API.
module ClustersHelper

  # @param [Hailstorm::Support::Configuration::ClusterBase] cluster_cfg
  # @param [Hailstorm::Model::Project] project
  # @return [Hash]
  def to_cluster_attributes(cluster_cfg, project: nil)
    attrs = case cluster_cfg.cluster_type
            when :amazon_cloud
              amazon_cloud_attrs(cluster_cfg)
            when :data_center
              data_center_attrs(cluster_cfg)
            else
              {}
            end

    attrs[:code] = cluster_cfg.cluster_code
    attrs[:disabled] = true if cluster_cfg.active == false

    if project
      cluster = Hailstorm::Model::Cluster.where(project: project)
                                         .find_by_cluster_code(cluster_cfg.cluster_code)
      if cluster
        attrs[:client_stats_count] = cluster.cluster_instance.client_stats.count
        attrs[:load_agents_count] = cluster.cluster_instance.load_agents.count
      end
    end

    deep_camelize_keys(attrs)
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
  # @return [Hailstorm::Support::Configuration::AmazonCloud]
  def amazon_cloud_config(cluster_config, api_params)
    # @type [Hailstorm::Support::Configuration::AmazonCloud] amz
    amz = cluster_config
    amz.access_key = api_params[:accessKey]
    amz.secret_key = api_params[:secretKey]
    amz.instance_type = api_params[:instanceType] unless api_params[:instanceType].blank?
    amz.max_threads_per_agent = api_params[:maxThreadsByInstance] unless api_params[:maxThreadsByInstance].blank?
    amz.region = api_params[:region] unless api_params[:region].blank?
    amz.vpc_subnet_id = api_params[:vpcSubnetId] unless api_params[:vpcSubnetId].blank?
    amz.base_ami = api_params[:baseAMI] unless api_params[:baseAMI].blank?
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
    dc.machines = to_array(api_params[:machines])
    dc.ssh_port = api_params[:port] if api_params[:port].presence
    dc
  end

  # @param [String] region
  # @return [String]
  def aws_cluster_title(region)
    "AWS #{region}"
  end

  # @param [Hailstorm::Support::Configuration::ClusterBase] cluster_cfg
  # @return [Integer]
  def compute_title_id(cluster_cfg)
    if cluster_cfg.cluster_type.to_sym != :amazon_cloud
      string_to_id(cluster_cfg.title)
    else
      string_to_id(aws_cluster_title(cluster_cfg.region))
    end
  end

  # @param [Hailstorm::Support::Configuration] hailstorm_config
  # @param [Integer] cluster_id
  # @return [Hailstorm::Support::Configuration::ClusterBase]
  def find_cluster_cfg(hailstorm_config, cluster_id)
    hailstorm_config.clusters.find { |cluster_cfg| cluster_id.to_i == compute_title_id(cluster_cfg) }
  end

  # @param [Hash] a_cluster
  # @param [Hash] b_cluster
  # @return [Fixnum]
  def sort_clusters(a_cluster, b_cluster)
    a_score = a_cluster['disabled'] ? 0 : 1
    b_score = b_cluster['disabled'] ? 0 : 1
    b_score <=> a_score
  end

  private

  def data_center_attrs(cluster_cfg)
    # @type [Hailstorm::Support::Configuration::DataCenter] dc
    dc = cluster_cfg
    {
      type: 'DataCenter',
      title: dc.title,
      id: string_to_id(dc.title),
      userName: dc.user_name,
      sshIdentity: { name: File.basename(dc.ssh_identity), path: File.dirname(dc.ssh_identity) },
      machines: dc.machines,
      port: dc.ssh_port
    }
  end

  def amazon_cloud_attrs(cluster_cfg)
    # @type [Hailstorm::Support::Configuration::AmazonCloud] amz
    amz = cluster_cfg
    title = aws_cluster_title(amz.region)
    {
      type: 'AWS',
      title: title,
      id: string_to_id(title),
      accessKey: amz.access_key,
      secretKey: amz.secret_key,
      instanceType: amz.instance_type,
      maxThreadsByInstance: amz.max_threads_per_agent,
      region: amz.region,
      vpcSubnetId: amz.vpc_subnet_id,
      baseAMI: amz.base_ami
    }
  end

  # @param [String] str
  # @return [Integer]
  def string_to_id(str)
    str.to_java_string.hash_code
  end

  # @param [Object] any
  # @return [Array]
  def to_array(any)
    any.is_a?(Array) ? any : [any]
  end

  # @param [Hailstorm::Support::Configuration::ClusterBase] cluster_config
  # @param [String] field_name
  # @param [Object] value
  # @return [Object]
  def query_field_value(cluster_config, field_name:, value:)
    field_value = value
    if field_name == :ssh_identity && cluster_config.cluster_type == :data_center
      field_value = "#{value['path']}/#{value['name']}"
    end

    field_value
  end

  # @param [Hailstorm::Support::Configuration::ClusterBase] cluster_config
  # @param [String] field_name
  def patch_request_valid?(cluster_config, field_name)
    return false if cluster_config.active == false && field_name != :active
    return false if field_name == :region
    return false if field_name == :base_ami && cluster_config.base_ami.blank?
    return false if field_name == :code

    true
  end
end
