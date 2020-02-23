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
    uri = URI("http://#{file_server_config[:host]}:#{file_server_config[:port]}/#{file_id}/#{file_name}")
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

  def read_identity_file(_file_path, _project_code = nil)
    super
  end

  def export_report(project_code, internal_path)
    logger.debug { "#{self.class}#{__method__}(#{internal_path})" }
    reports_uri = URI.parse("http://#{file_server_config[:host]}:#{file_server_config[:port]}/reports")
    http = Net::HTTP.new(reports_uri.host, reports_uri.port)
    request = Net::HTTP::Post.new(reports_uri.request_uri)
    request.body = Rack::Multipart::Generator.new({
      file: Rack::Multipart::UploadedFile.new(internal_path),
      prefix: project_code
    }.stringify_keys).dump

    request.content_type = "multipart/form-data, boundary=#{Rack::Multipart::MULTIPART_BOUNDARY}"
    # @type [Net::HTTPResponse]
    response = http.request(request)
    raise(Net::HTTPError.new("Failed upload to #{reports_uri}", response)) unless response.is_a?(Net::HTTPSuccess)

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

  private

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
