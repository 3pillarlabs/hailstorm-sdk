require 'sidekiq'
require 'hailstorm/application'
require 'fileutils'
require 'erubis'
require 'logger/custom_logger'
require 'uri'
require 'net/http'

class HailstormProcess
  include Sidekiq::Worker

  @@hailstorm_pool = {}

  def perform(app_name, app_root_path, app_process, project_id=nil, callback=nil, upload_directory_path=nil, environment_data=nil, result_ids = nil)
    puts "configure application"
    puts "app name : "+app_name
    puts "app root path : "+app_root_path

    #call process on projects based on app_process
    case app_process
      when 'setup'
        project_setup(app_name, app_root_path, callback, upload_directory_path, project_id, environment_data)
      when 'stop'
        project_stop(app_name, app_root_path, project_id, callback)
      when 'start', 'abort', 'terminate'
        process_request(app_name, app_root_path, project_id, app_process, callback)
      when 'status'
        project_status(app_name, app_root_path, project_id, callback)
      when 'download'
        project_results_download(app_name, app_root_path, project_id, result_ids, callback)
      when 'export'
        project_results_export(app_name, app_root_path, project_id, result_ids, callback)
    end

    puts "application configuration ended"
  end

  def set_hailstorm_in_pool_if_not_exists(project_id_str, app_name, app_root_path)
    app_boot_file_path = File.join(app_root_path, app_name, 'config/boot.rb')

    #create custom_logger instance
    log_file_path = File.join(app_root_path, app_name, 'log/hailstorm_status.log')
    logfile = File.open(log_file_path, File::WRONLY | File::APPEND | File::CREAT)
    logfile.sync = true #automatically flushes data to file
    custom_logger = CustomLogger.new(logfile) #constant accessible anywhere
    custom_logger_config = {:level => Logger::INFO}
    custom_logger.level = custom_logger_config[:level] #change log level

    if @@hailstorm_pool[project_id_str] == nil
      puts "*** hailstorm object does not exists in pool for project id :"+project_id_str
      Hailstorm::Application.initialize!(app_name, app_boot_file_path, custom_logger)
      @@hailstorm_pool[project_id_str] = Hailstorm.application
    else
      puts "*** hailstorm object already exists in pool for project id :"+project_id_str
      @@hailstorm_pool[project_id_str].set_hailstorm_configuration(app_name, app_boot_file_path, custom_logger)
    end

  end


  def project_setup(app_name, app_root_path, callback, upload_directory_path, project_id, environment_data)
    puts "application setup process started"

    project_id_str = project_id.to_s
    hailstormObj = Hailstorm::Application.new
    app_directory = File.join(app_root_path, app_name)
    if !File.directory?(app_directory)
      #create app directory structure
      hailstormObj.create_project(app_root_path, app_name)

      #change database.properties file and add password to it
      app_database_file_path = File.join(app_directory, 'config/database.properties')
      dbtext = File.read(app_database_file_path)
      File.write(app_database_file_path, dbtext.gsub(/password =/, "password = sa"))

      #change GEM hailstorm path
      app_gem_file_path = File.join(app_directory, 'Gemfile')
      gemtext = File.read(app_gem_file_path)
      File.write(app_gem_file_path, gemtext.gsub(/"hailstorm"/, '"hailstorm", :path=> "/home/ravish/hailstorm_projects/hailstorm-gem/"'))

    end

    #copy jmx file to app jmeter directory
    sourcejmx_file_path = File.join(upload_directory_path, 'Jmx_Files', project_id_str, "/.")
    destjmx_file_path = File.join(app_directory, 'jmeter/')
    FileUtils.cp_r sourcejmx_file_path, destjmx_file_path

    #copy ssh identity file to config
    source_sshidentity_filepath = File.join(upload_directory_path, 'ssh_identity_Files', project_id_str, "/.")
    dest_sshidentity_filepath = File.join(app_directory, 'config/')
    FileUtils.cp_r source_sshidentity_filepath, dest_sshidentity_filepath

    #create enviroment file for app
    template_directory = File.join(Dir.pwd, 'lib', 'templates')

    environment_template = Erubis::Eruby.new(File.read(template_directory+"/environment.erb"))
    jmeter_template = Erubis::Eruby.new(File.read(template_directory+"/jmeter_config.erb"))
    ec2_config_template = Erubis::Eruby.new(File.read(template_directory+"/ec2_config.erb"))
    data_center_template = Erubis::Eruby.new(File.read(template_directory+"/data_center.erb"))

    jmeter_config_str = environment_data['test_plans_data'].blank? ? "" : jmeter_template.result(:test_plans_data => environment_data['test_plans_data'])
    ec2_config_str = environment_data['amazon_clouds_data'].blank? ? "" : ec2_config_template.result(:amazon_clouds_data => environment_data['amazon_clouds_data'])
    data_center_config_str = environment_data['data_centers_data'].blank? ? "" : data_center_template.result(:data_centers_data => environment_data['data_centers_data'])

    env_file_path = File.join(app_directory, 'config/environment.rb')
    envstr = environment_template.result(:jmeter_config => jmeter_config_str, :ec2_config => ec2_config_str, :data_center_config => data_center_config_str)
    File.open(env_file_path, 'w') { |file| file.write(envstr) }

    #get hailstorm object from pool
    set_hailstorm_in_pool_if_not_exists(project_id_str, app_name, app_root_path)

    #now setup app configuration
    @@hailstorm_pool[project_id_str].current_project.setup

    #callback to web
    project_callback(callback)

    puts "application setup process ended"
  end

  def process_request(app_name, app_root_path, project_id, command, callback)
    puts "application "+command+" process started for "+app_name

    project_id_str = project_id.to_s

    #get hailstorm object from pool
    set_hailstorm_in_pool_if_not_exists(project_id_str, app_name, app_root_path)

    #now process request command
    @@hailstorm_pool[project_id_str].current_project.send(command)

    if(command == "start")
      HailstormProcess.perform_async(app_name, app_root_path, 'status', project_id, callback)
    end

    #callback to web
    project_callback(callback)

    puts "application "+command+" process ended for "+app_name
  end

  def project_stop(app_name, app_root_path, project_id, callback)
    puts "in stop project worker of "+app_name

    project_id_str = project_id.to_s

    #get hailstorm object from pool
    set_hailstorm_in_pool_if_not_exists(project_id_str, app_name, app_root_path)

    #get execution cycle data
    execution_cycle_data = @@hailstorm_pool[project_id_str].current_project.current_execution_cycle

    #stop project process
    @@hailstorm_pool[project_id_str].current_project.stop

    #format execution_cycle_data
    execution_data = Hash.new
    execution_data[:execution_cycle_id] = execution_cycle_data.id
    execution_data[:project_id] = execution_cycle_data.project_id
    execution_data[:total_threads_count] = execution_cycle_data.total_threads_count
    execution_data[:avg_90_percentile] = execution_cycle_data.avg_90_percentile.to_s
    execution_data[:avg_tps] = execution_cycle_data.avg_tps.round(2).to_s
    execution_data[:started_at] = execution_cycle_data.started_at.strftime('%Y-%m-%d %H:%M')
    execution_data[:stopped_at] = Time.now.utc.strftime('%Y-%m-%d %H:%M')

    #callback to web
    callback_stop = callback+"&"+execution_data.to_query
    project_callback(callback_stop)

    puts "application stop process ended"
  end

  def project_status(app_name, app_root_path, project_id, callback)
    puts "application status process started for"+app_name

    project_id_str = project_id.to_s

    #get hailstorm object from pool
    set_hailstorm_in_pool_if_not_exists(project_id_str, app_name, app_root_path)

    #get status of project tests process
    tests_status = nil
    if(@@hailstorm_pool[project_id_str].current_project.current_execution_cycle.nil?)
      tests_status = 'empty'
    else
      running_agents = @@hailstorm_pool[project_id_str].current_project.check_status()
      tests_status = running_agents.empty? ? 'completed' : 'running'
    end

    if(tests_status == 'completed')
      puts "all tests stopped now submitting job for stop"
      callback.gsub!('start', 'stop')
      HailstormProcess.perform_async(app_name, app_root_path, 'stop', project_id, callback, nil, nil)
    elsif(tests_status == 'running')
      sleep(10)
      puts "tests still running submitting job for status"
      HailstormProcess.perform_async(app_name, app_root_path, 'status', project_id, callback, nil, nil)
    end

    puts "application status process ended for"+app_name
  end

  def project_results_download(app_name, app_root_path, project_id, result_ids, callback)
    puts "in project results download worker of "+app_name

    project_id_str = project_id.to_s

    #get hailstorm object from pool
    set_hailstorm_in_pool_if_not_exists(project_id_str, app_name, app_root_path)

    #now process request for results
    @@hailstorm_pool[project_id_str].current_project.results("report", result_ids)

    #callback to web
    project_callback(callback)

    puts "application result download process ended"
  end

  def project_results_export(app_name, app_root_path, project_id, result_ids, callback)
    puts "in project results export worker of "+app_name

    project_id_str = project_id.to_s

    #get hailstorm object from pool
    set_hailstorm_in_pool_if_not_exists(project_id_str, app_name, app_root_path)

    #now process request for results
    @@hailstorm_pool[project_id_str].current_project.results(:export, result_ids)

    #callback to web
    project_callback(callback)

    puts "applicationexportdownload process ended"
  end

  def project_callback(callback)
    url = URI.parse(callback)
    req = Net::HTTP::Get.new(url.to_s)
    res = Net::HTTP.start(url.host, url.port) {|http|
      http.request(req)
    }
  end

end