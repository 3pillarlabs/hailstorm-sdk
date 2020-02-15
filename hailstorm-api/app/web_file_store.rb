require 'net/http'
require 'uri'
require 'yaml'

require 'hailstorm/behavior/file_store'

class WebFileStore
  include Hailstorm::Behavior::FileStore

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

  private

  def file_server_config
    return @file_server_config if @file_server_config

    config_file_path = File.expand_path('../../config/file_server.yml', __FILE__)
    config = YAML.load_file(config_file_path)
    @file_server_config = config[Hailstorm.env.to_s].symbolize_keys
  end
end
