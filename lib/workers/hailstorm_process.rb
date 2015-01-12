require 'sidekiq'
require 'hailstorm/application'
require 'fileutils'
require 'erubis'

class HailstormProcess
  include Sidekiq::Worker

  @@hailstorm_pool = {}

  def perform(app_name, app_root_path, app_process, project_id=nil, callback=nil, upload_directory_path=nil, environment_data=nil)
    puts "configure application"
    puts "app name : "+app_name
    puts "app root path : "+app_root_path

    #call process on projects based on app_process
    case app_process
      when 'setup'
        project_setup(app_name, app_root_path, callback, upload_directory_path, project_id, environment_data)
      when 'start', 'stop', 'abort', 'terminate'
        process_request(app_name, app_root_path, project_id, app_process, callback)
      when 'results'
        project_results(app_name, app_root_path, project_id)
    end

    puts "application configuration ended"
  end

  def set_hailstorm_in_pool_if_not_exists(project_id_str, app_name, app_root_path)
    app_boot_file_path = File.join(app_root_path, app_name, 'config/boot.rb')
    if @@hailstorm_pool[project_id_str] == nil
      puts "*** hailstorm object does not exists in pool for project id :"+project_id_str
      Hailstorm::Application.initialize!(app_name,app_boot_file_path)
      @@hailstorm_pool[project_id_str] = Hailstorm.application
    else
      puts "*** hailstorm object already exists in pool for project id :"+project_id_str
    end

    puts "2: project ids having objects in pool: "+@@hailstorm_pool.keys.inspect

    puts "****current project: "
    puts @@hailstorm_pool[project_id_str].current_project.inspect
  end


  def project_setup(app_name, app_root_path, callback, upload_directory_path, project_id, environment_data)
    project_id_str = project_id.to_s
    hailstormObj = Hailstorm::Application.new
    app_directory = File.join(app_root_path, app_name)
    if !File.directory?(app_directory)
      #create app directory structure
      hailstormObj.create_project(app_root_path,app_name)

      #place log4j file in config directory of project
      log_source_file_path = File.join(Dir.pwd, 'lib', 'templates/log4j.xml')
      log_dest_file_path = File.join(app_directory, 'config/')
      FileUtils.cp log_source_file_path, log_dest_file_path

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

    #setup database by initializing application
    # app_boot_file_path = File.join(app_directory, 'config/boot.rb')
    set_hailstorm_in_pool_if_not_exists(project_id_str, app_name, app_root_path)

    #now setup app configuration
    @@hailstorm_pool[project_id_str].interpret_command("setup")

    system ("curl #{callback}")

    puts "application setup process ended"
  end

  def process_request(app_name, app_root_path, project_id, command, callback)
    project_id_str = project_id.to_s
    puts "in "+command+" project worker of "+app_name
    app_boot_file_path = File.join(app_root_path, app_name, 'config/boot.rb')
    #Hailstorm::Application.initialize!(app_name,app_boot_file_path)

    set_hailstorm_in_pool_if_not_exists(project_id_str, app_name, app_root_path)

    #now setup app configuration
    @@hailstorm_pool[project_id_str].interpret_command(command)

    puts "callback to: "+callback
    system ("curl #{callback}")

    puts "application "+command+" process ended"
  end

  def project_results(app_name, app_root_path, project_id)
    project_id_str = project_id.to_s
    puts "in project results worker of "+app_name
    app_boot_file_path = File.join(app_root_path, app_name, 'config/boot.rb')
    #Hailstorm::Application.initialize!(app_name,app_boot_file_path)

    #now setup app configuration
    Hailstorm.application.interpret_command("results report")

    puts "application result process ended"
  end

end