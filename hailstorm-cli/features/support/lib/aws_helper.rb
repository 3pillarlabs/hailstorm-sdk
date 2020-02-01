module AwsHelper

  def aws_keys
    @keys ||= [].tap {|vals|
      require 'yaml'
      key_file_path = File.expand_path('../../../data/keys.yml', __FILE__)
      keys = YAML.load_file(key_file_path)
      vals << keys['access_key']
      vals << keys['secret_key']
    }
  end

  def tagged_instance(tag_value, region = 'us-east-1', status = :running, tag_key = :Name)
    require 'aws-sdk-v1'
    config = {}
    config[:access_key_id], config[:secret_access_key] = aws_keys
    @ec2 = AWS::EC2.new(config).regions[region]
    @ec2.instances
        .select {|instance| instance.status == status }
        .find {|instance| instance.tags[tag_key] =~ Regexp.new(tag_value, Regexp::IGNORECASE)}
  end

  def write_site_server_url(server_name)
    require 'fileutils'
    FileUtils.mkdir_p(File.dirname(site_server_url_path))
    File.open(site_server_url_path, 'w') do |file|
      file.print(server_name)
    end
  end

  def site_server_url_path
    File.join(tmp_path, 'site_server.txt')
  end
end

World(AwsHelper)