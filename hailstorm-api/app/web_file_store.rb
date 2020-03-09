require 'net/http'
require 'uri'
require 'yaml'
require 'rack'
require 'net/http'
require 'json'

require 'hailstorm/behavior/loggable'
require 'hailstorm/behavior/file_store'
require 'hailstorm/model/project'
require 'model/project_configuration'
require 'helpers/api_helper'

class WebFileStore
  include Hailstorm::Behavior::Loggable
  include Hailstorm::Behavior::FileStore
  include ApiHelper

  # Fetch a file from file-store
  # @param [String] file_id
  # @param [String] file_name
  # @param [String] to_path
  # @return [String] full path to copied file
  def fetch_file(file_id:, file_name:, to_path:)
    uri = build_fs_url(file_id: file_id, file_name: file_name)
    response = Net::HTTP.get_response(uri)
    raise(Net::HTTPError.new("Failed to fetch #{uri}", response)) unless response.is_a?(Net::HTTPSuccess)
    File.open("#{to_path}/#{file_name}", 'w') do |out|
      out.write(response.body)
    end

    "#{to_path}/#{file_name}"
  end
  
  def fetch_jmeter_plans(project_code)
    project_config = project_config(project_code)
    return [] unless project_config

    # @type [Hailstorm::Support::Configuration]
    hailstorm_config = deep_decode(project_config.stringified_config)
    hailstorm_config.jmeter.test_plans
  end

  # @return [Hash] { 'app' => nil }
  def app_dir_tree(_project_code, *_args)
    parent_node = {}
    parent_node[Hailstorm.app_dir] = nil
    parent_node
  end

  # Copy all artifacts to location as flat list of files (skip directories)
  def transfer_jmeter_artifacts(project_code, to_path)
    project_config = project_config(project_code)
    return unless project_config

    # @type [Hailstorm::Support::Configuration]
    hailstorm_config = deep_decode(project_config.stringified_config)
    hailstorm_config.jmeter.test_plans.each do |file_path|
      logger.debug { file_path }
      file_id, file_name = file_path.split('/')
      fetch_file(file_id: file_id, file_name: "#{file_name}.jmx", to_path: to_path)
    end

    hailstorm_config.jmeter.data_files.each do |file_path|
      file_id, file_name = file_path.split('/')
      fetch_file(file_id: file_id, file_name: file_name, to_path: to_path)
    end
  end

  # @param [String] file_path
  def normalize_file_path(file_path)
    file_path.split('/').second || file_path
  end

  def read_identity_file(file_path, _project_code = nil)
    logger.debug { file_path }
    file_id, file_name = file_path.split('/')
    uri = build_fs_url(file_id: file_id, file_name: file_name)
    Net::HTTP.start(uri.hostname, uri.port) do |http|
      req = Net::HTTP::Get.new(uri)
      http.request(req) do |res|
        raise(Net::HTTPError.new("Failed to fetch #{uri}", res)) unless res.is_a?(Net::HTTPSuccess)

        content = res.body
        yield StringIO.new(content)
      end
    end
  end

  def export_report(project_code, internal_path)
    reports_uri = URI.parse("http://#{file_server_config[:host]}:#{file_server_config[:port]}/reports")
    response = upload_file(internal_path, reports_uri, project_code)
    data = JSON.parse(response.body).symbolize_keys
    ["#{reports_uri}/#{project_code}/#{data[:id]}/#{data[:originalName]}", data[:id]]
  end

  # @param [String] project_code
  # @return [Array<Hash>] hash.keys = %w[id, title, uri]
  def fetch_reports(project_code)
    scheme_host_port = "http://#{file_server_config[:host]}:#{file_server_config[:port]}"
    uri_path = "#{scheme_host_port}/reports/#{project_code}"
    reports_uri = URI.parse(uri_path)
    response = Net::HTTP.get_response(reports_uri)
    raise(Net::HTTPError.new("Failed to fetch #{reports_uri}", response)) unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body).map do |attrs|
      symbol_attrs = attrs.symbolize_keys
      symbol_attrs.merge(uri: "#{uri_path}/#{symbol_attrs[:id]}/#{symbol_attrs[:title]}")
    end
  end

  # @param [String] project_code
  # @param [String] abs_jtl_path path to JTL file
  # @return [Hash] hash.keys = %w[title url]
  def export_jtl(project_code, abs_jtl_path)
    scheme_host_port = "http://#{file_server_config[:host]}:#{file_server_config[:port]}"
    uri = URI("#{scheme_host_port}/upload")
    response = upload_file(abs_jtl_path, uri, project_code)
    data = JSON.parse(response.body).symbolize_keys
    {
      title: data[:originalName],
      url: "#{scheme_host_port}/#{data[:id]}/#{data[:originalName]}"
    }
  end

  private

  def build_fs_url(file_id:, file_name:)
    URI("http://#{file_server_config[:host]}:#{file_server_config[:port]}/#{file_id}/#{file_name}")
  end

  # @return [Net::HTTPResponse]
  def upload_file(file_path, uri, prefix)
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Post.new(uri.request_uri)
    request.body = Rack::Multipart::Generator.new({
      file: Rack::Multipart::UploadedFile.new(file_path),
      prefix: prefix
    }.stringify_keys).dump

    request.content_type = "multipart/form-data, boundary=#{Rack::Multipart::MULTIPART_BOUNDARY}"
    response = http.request(request)
    raise(Net::HTTPError.new("Failed upload to #{uri}", response)) unless response.is_a?(Net::HTTPSuccess)
    response
  end

  def project_config(project_code)
    project = Hailstorm::Model::Project.find_by_project_code!(project_code)
    ProjectConfiguration.where(project_id: project.id).first
  end

  def file_server_config
    return @file_server_config if @file_server_config

    config_file_path = File.expand_path('../../config/file_server.yml', __FILE__)
    config = YAML.load_file(config_file_path)
    @file_server_config = config[Hailstorm.env.to_s].symbolize_keys
  end
end
