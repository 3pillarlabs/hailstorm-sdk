module AwsHelper

  def aws_keys
    @keys ||= [].tap {|vals|
      require 'yaml'
      key_file_path = File.expand_path('../../data/keys.yml', __FILE__)
      keys = YAML.load_file(key_file_path)
      vals << keys['access_key']
      vals << keys['secret_key']
    }
  end
end
