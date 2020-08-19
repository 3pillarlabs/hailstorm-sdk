module CliStepHelper
  def tmp_path
    build_path
  end

  def data_path
    File.expand_path('../../../data', __FILE__)
  end

  def current_project(new_project = nil)
    @app_name ||= new_project
  end

  def jmeter_properties(hashes = nil)
    if hashes
      @jmeter_properties = hashes.collect { |e| OpenStruct.new(e) }
      @config_changed = true
    end
    @jmeter_properties || []
  end

  def clusters(hashes = nil)
    if hashes
      keys = OpenStruct.new(YAML.load_file(File.join(data_path, 'keys.yml')))
      @clusters = hashes.collect do |e|
        s = OpenStruct.new(e)
        s.access_key = keys.access_key if s.access_key.nil? && s.cluster_type == :amazon_cloud
        s.secret_key = keys.secret_key if s.secret_key.nil? && s.cluster_type == :amazon_cloud
        s.active = true if s.active.nil?
        s
      end
      @config_changed = true
    end
    @clusters || []
  end

  def config_changed?
    @config_changed
  end

  def write_config(monitor_active = true)
    lookup_context = ActionView::LookupContext.new([data_path])
    engine = ActionView::Base.with_empty_template_cache.new(lookup_context)
    site_server_property = OpenStruct.new(property: 'ServerName', value: site_server_url)
    engine.assign(
      properties: jmeter_properties.push(site_server_property),
      clusters: clusters,
      monitor_host: site_server_url,
      monitor_active: monitor_active || false
    )

    File.open(File.join(tmp_path, current_project,
                        Hailstorm.config_dir, 'environment.rb'), 'w') do |env_file|
      env_file.print(engine.render(template: 'environment', formats: [:text], handlers: [:erb]))
    end
    @config_changed = false
  end

  def aws_keys
    @keys ||= [].tap {|vals|
        require 'yaml'
        key_file_path = File.expand_path('../../data/keys.yml', __FILE__)
        keys = YAML.load_file(key_file_path)
        vals << keys['access_key']
        vals << keys['secret_key']
    }
  end

  def site_server_url_path
    File.join(tmp_path, 'site_server.txt')
  end

  def site_server_url
    File.open(site_server_url_path) do |file|
      file.read.chomp
    end
  rescue Errno::ENOENT
    'integration.hailstorm.org'
  end

  def local_site_ip_path
    File.join(data_path, 'site_server.txt')
  end
end

