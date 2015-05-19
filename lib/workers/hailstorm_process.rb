require 'sidekiq'
require 'hailstorm/application'
require 'fileutils'
require 'erubis'
require 'uri'
require 'net/http'

class HailstormProcess

  include Sidekiq::Worker

  def perform(app_name, app_root_path, app_process, project_id = nil, callback = nil, upload_dir_path = nil, environment_data = nil, result_ids = nil, error_callback = nil)
    puts 'configure application'
    puts ["app_name: #{app_name}",
          "app_root_path: #{app_root_path}",
          "app_process: #{app_process}",
          "project_id: #{project_id}",
          "callback: #{callback}",
          "upload_dir_path: #{upload_dir_path}",
          "environment_data: #{environment_data}",
          "result_ids: #{result_ids}",
          "error_callback: #{error_callback}"].join("\n")

    begin
      # call process on projects based on app_process
      case app_process
        when 'setup'
          project_setup(app_name, app_root_path, callback, upload_dir_path, project_id, environment_data)
        when 'stop'
          project_stop(app_name, app_root_path, project_id, callback)
        when 'start', 'abort', 'terminate'
          process_request(app_name, app_root_path, project_id, app_process, callback, environment_data, upload_dir_path)
        when 'status'
          project_status(app_name, app_root_path, callback)
        when 'download'
          project_results_download(app_name, app_root_path, project_id, result_ids, callback)
        when 'export'
          project_results_export(app_name, app_root_path, project_id, result_ids, callback)
        else
          # unknown command
          raise('Unknown command')
      end
    rescue Exception => exception
      puts exception.message
      puts exception.backtrace.join("\n")
			begin
      	# Call the error_callback if provided
      	error_callback(error_callback, app_process, exception) if error_callback
			rescue => e
				# silence!
				puts e.message
        puts e.backtrace.join("\n")
			end
    end

    puts 'application configuration ended'
  end

  def project_setup(app_name, app_root_path, callback, upload_dir_path, project_id, environment_data)
    puts 'application setup process started'

    hailstorm_inst = Hailstorm::Application.new

    # create enviroment file for app
    template_directory = File.join(Dir.pwd, 'lib', 'templates')

    # create app directory structure
    app_directory = hailstorm_inst.create_project(app_root_path, app_name)

    # copy log4j.xml to config directory
    FileUtils.cp File.join(template_directory, 'log4j.xml'), File.join(app_directory, 'config')

    # copy jmx file to app jmeter directory
    configure_project(environment_data, project_id, template_directory, upload_dir_path, app_directory)

    # now setup app configuration
    execute_hailstorm_command(app_directory, :setup, %w[force])

    # callback to web
    project_callback(callback)

    puts 'application setup process ended'
  end

  def configure_project(environment_data, project_id, template_directory, upload_dir_path, app_directory)
    sourcejmx_file_path = File.join(upload_dir_path, 'Jmx_Files', project_id.to_s, '/.')
    destjmx_file_path = File.join(app_directory, 'jmeter/')
    FileUtils.cp_r sourcejmx_file_path, destjmx_file_path

    # copy ssh identity file to config
    source_sshidentity_filepath = File.join(upload_dir_path, 'ssh_identity_Files', project_id.to_s, '/.')
    if File.exist? source_sshidentity_filepath
      dest_sshidentity_filepath = File.join(app_directory, 'config/')
      FileUtils.cp_r source_sshidentity_filepath, dest_sshidentity_filepath
    end

    environment_template = Erubis::Eruby.new(File.read(template_directory + '/environment.erb'))
    jmeter_template = Erubis::Eruby.new(File.read(template_directory + '/jmeter_config.erb'))
    ec2_config_template = Erubis::Eruby.new(File.read(template_directory + '/ec2_config.erb'))
    data_center_template = Erubis::Eruby.new(File.read(template_directory + '/data_center.erb'))

    jmeter_config_str = environment_data['test_plans_data'].blank? ? '' : jmeter_template.result(:test_plans_data => environment_data['test_plans_data'])
    ec2_config_str = environment_data['amazon_clouds_data'].blank? ? '' : ec2_config_template.result(:amazon_clouds_data => environment_data['amazon_clouds_data'])
    data_center_config_str = environment_data['data_centers_data'].blank? ? '' : data_center_template.result(:data_centers_data => environment_data['data_centers_data'])

    env_file_path = File.join(app_directory, 'config/environment.rb')
    envstr = environment_template.result(:jmeter_config => jmeter_config_str, :ec2_config => ec2_config_str, :data_center_config => data_center_config_str)
    File.open(env_file_path, 'w') { |file| file.write(envstr) }
  end

  # Process 'start', 'abort', 'terminate'
  def process_request(app_name, app_root_path, project_id, command, callback, environment_data = nil, upload_dir_path = nil)
    puts "application #{command} process started for #{app_name}"

    app_dir_path = File.join(app_root_path, app_name)
    # system("cd #{app_dir_path};HAILSTORM_ENV=sidekiq script/hailstorm --cmd #{command}")
    if command.to_sym == :start
      args = %w[redeploy]
      template_directory = File.join(Dir.pwd, 'lib', 'templates')
      configure_project(environment_data, project_id, template_directory, upload_dir_path, app_dir_path)
    end

    execute_hailstorm_command(app_dir_path, command, args)

    #callback to web
    project_callback(callback)

    puts "application #{command} process ended for #{app_name}"
  end

  def project_stop(app_name, app_root_path, project_id, callback)
    puts "in stop project worker of #{app_name}"

    app_path = File.join(app_root_path, app_name)
    execute_hailstorm_command(app_path, :stop)
    data = execute_hailstorm_command(app_path, :results, %w[show last], :json)
    project_callback(callback, {:data => data})

    puts 'application stop process ended'
  end

  def project_status(app_name, app_root_path, callback)
    app_path = File.join(app_root_path, app_name)
    response = execute_hailstorm_command(app_path, :status, nil, :json)
    project_callback(callback, {:status_data => response}) unless response.nil? or response.empty?
  end

  def project_results_download(app_name, app_root_path, project_id, result_ids, callback)
    puts "in project results download worker of #{app_name}"

    app_path = File.join(app_root_path, app_name)
    args = %w[report]
    args.push(result_ids.join(':')) unless result_ids.nil? or result_ids.empty?
    execute_hailstorm_command(app_path, :results, args)

    # callback to web
    project_callback(callback)

    puts 'application result download process ended'
  end

  def project_results_export(app_name, app_root_path, project_id, result_ids, callback)
    puts "in project results export worker of #{app_name}"

    app_path = File.join(app_root_path, app_name)
    args = %w[export]
    args.push(result_ids.join(':')) unless result_ids.nil? or result_ids.empty?
    execute_hailstorm_command(app_path, :results, args)

    #callback to web
    project_callback(callback)

    puts 'applicationexportdownload process ended'
  end

  def project_callback(callback, data = {})
    url = URI.parse(callback)
    req = Net::HTTP::Post.new(url.to_s)
    req.set_form_data(data || {})
    Net::HTTP.start(url.host, url.port) {|http|
      http.request(req)
    }
  end

  # @param callback [String]
  # @param command [String]
  # @param exception [Exception]
  def error_callback(callback, command, exception)
    url = URI.parse(callback)
    req = Net::HTTP::Post.new(url.to_s)
    req.set_form_data({message: exception.message, command: command})
    Net::HTTP.start(url.host, url.port) {|http|
      http.request(req)
    }
  end

  # @param [String] app_path path to Hailstorm app
  # @param [String] command
  # @param [Array] args
  # @param [Symbol] format
  def execute_hailstorm_command(app_path, command, args = nil, format = nil)

    system_args = [
        'cd',
        "#{app_path};HAILSTORM_ENV=sidekiq",
        'script/hailstorm',
        '--cmd',
        "#{command}"
    ]

    system_args.push('--args', args.join(',')) unless args.nil?
    system_args.push('--format', format) unless format.nil?

    # system(system_args.join(' '))
    `#{system_args.join(' ')}`
  end

end
