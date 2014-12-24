require 'sidekiq'
require 'hailstorm/application'
require 'fileutils'
require 'erubis'

class HailstormSetup
  include Sidekiq::Worker

  def perform(app_name, app_root_path, upload_directory_path, project_id, environment_data)
    puts "configure application"
    puts "app name : "+app_name
    puts "app root path : "+app_root_path
    puts "project id : "+project_id.to_s

    template_directory = File.join(Dir.pwd, 'lib', 'templates')


    environment_template = Erubis::Eruby.new(File.read(template_directory+"/environment.erb"))
    jmeter_template = Erubis::Eruby.new(File.read(template_directory+"/jmeter_config.erb"))
    ec2_config_template = Erubis::Eruby.new(File.read(template_directory+"/ec2_config.erb"))
    data_center_template = Erubis::Eruby.new(File.read(template_directory+"/data_center.erb"))

    jmeter_config_str = environment_data['test_plans_data'].blank? ? "" : jmeter_template.result(:test_plans_data => environment_data['test_plans_data'])
    ec2_config_str = environment_data['amazon_clouds_data'].blank? ? "" : ec2_config_template.result(:amazon_clouds_data => environment_data['amazon_clouds_data'])
    data_center_config_str = environment_data['data_centers_data'].blank? ? "" : data_center_template.result(:data_centers_data => environment_data['data_centers_data'])

    hailstormObj = Hailstorm::Application.new
    app_directory = File.join(app_root_path, app_name)
    if !File.directory?(app_directory)
      #create app directory structure
      hailstormObj.create_project(app_root_path,app_name)

      #change database.properties file and add password to it
      app_database_file_path = File.join(app_directory, 'config/database.properties')
      dbtext = File.read(app_database_file_path)
      File.write(app_database_file_path, dbtext.gsub(/password =/, "password = sa"))

      #change GEM hailstorm path
      app_gem_file_path = File.join(app_directory, 'Gemfile')
      gemtext = File.read(app_gem_file_path)
      File.write(app_gem_file_path, gemtext.gsub(/"hailstorm"/, '"hailstorm", :path=> "/home/ravish/Projects/demosidekiq/hailstorm-gem/"'))

    end

    #copy jmx file to app jmeter directory
    sourcejmx_file_path = File.join(upload_directory_path, 'Jmx_Files', project_id.to_s, "/.")
    destjmx_file_path = File.join(app_directory, 'jmeter/')

    puts "**** copying JMX files from source: "+sourcejmx_file_path+" to destination: "+destjmx_file_path
    FileUtils.cp_r sourcejmx_file_path, destjmx_file_path

    #create enviroment file for app
    env_file_path = File.join(app_directory, 'config/environment.rb')
    envstr = environment_template.result(:jmeter_config => jmeter_config_str, :ec2_config => ec2_config_str, :data_center_config => data_center_config_str)
    File.open(env_file_path, 'w') { |file| file.write(envstr) }

    #setup database by initializing application
    app_boot_file_path = File.join(app_directory, 'config/boot.rb')
    #puts "app boot file path : "+app_boot_file_path
    Hailstorm::Application.initialize!(app_name,app_boot_file_path)

    #now setup app configuration
    #Hailstorm.application.interpret_command("setup")

    puts "application configuration ended"
  end


end