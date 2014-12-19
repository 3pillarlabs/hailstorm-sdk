require 'sidekiq'
require 'hailstorm/application'
require 'fileutils'
require 'erubis'
require 'active_record'

class HailstormSetup
  include Sidekiq::Worker

  def perform(app_name, app_root_path, upload_directory_path, project_id, environment_data)
    puts "configure application"
    puts "app name : "+app_name
    puts "app root path : "+app_root_path
    # puts "upload directory path : "+upload_directory_path
    puts "project id : "+project_id.to_s

    template_directory = File.join(Dir.pwd, 'lib', 'templates')
    # puts "template dir="+template_directory


    environment_template = Erubis::Eruby.new(File.read(template_directory+"/environment.erb"))
    jmeter_template = Erubis::Eruby.new(File.read(template_directory+"/jmeter_config.erb"))
    ec2_config_template = Erubis::Eruby.new(File.read(template_directory+"/ec2_config.erb"))
    data_center_template = Erubis::Eruby.new(File.read(template_directory+"/data_center.erb"))

    data_center_config_str = ''
    ec2_config_str = ''
    jmeter_config_str = jmeter_template.result()
    ec2_config_str = ec2_config_template.result(:amazon_clouds_data => environment_data['amazon_clouds_data'])
    data_center_config_str = data_center_template.result(:data_centers_data => environment_data['data_centers_data'])

    puts "********* env data=="
    puts environment_data.inspect

    puts "********* amazon cloud data=="
    puts environment_data['amazon_clouds_data'].inspect

    # testStr = JSON.dump environment_data

    # phera = Array.new
    # phera = ["ph1", "ph2", "ph3"]
    puts "vv==="+environment_template.result(:jmeter_config => jmeter_config_str, :ec2_config => ec2_config_str, :data_center_config => data_center_config_str)
    #
    # hailstormObj = Hailstorm::Application.new
    # app_directory = File.join(app_root_path, app_name)
    # if !File.directory?(app_directory)
    #   #create app directory structure
    #   hailstormObj.create_project(app_root_path,app_name)
    #
    #   #change database.properties file and add password to it
    #   app_database_file_path = File.join(app_directory, 'config/database.properties')
    #   dbtext = File.read(app_database_file_path)
    #   File.write(app_database_file_path, dbtext.gsub(/password =/, "password = sa"))
    #
    #   #change GEM hailstorm path
    #   app_gem_file_path = File.join(app_directory, 'Gemfile')
    #   gemtext = File.read(app_gem_file_path)
    #   File.write(app_gem_file_path, gemtext.gsub(/"hailstorm"/, '"hailstorm", :path=> "/home/ravish/hailstorm_projects/hailstorm-gem/"'))
    #
    # end
    #
    # #copy jmx file to app jmeter directory
    # sourcejmx_file_path = File.join(app_root_path, "testproject5", 'jmeter/ASP_SHOP.jmx')
    # destjmx_file_path = File.join(app_directory, 'jmeter/')
    # FileUtils.cp(sourcejmx_file_path,destjmx_file_path)
    #
    # #create enviroment file for app
    # env_file_path = File.join(app_directory, 'config/environment.rb')
    #
    # envstr = "# Hailstorm configuration \n"
    # envstr += "Hailstorm.application.config do |config|\n"
    #
    # #JMeter configuration
    # envstr += "\n\n\t# This is the JMeter configuration\n"
    # envstr += "\tconfig.jmeter do |jmeter|\n"
    # envstr += "\t\tjmeter.properties do |map|\n"
    # envstr += "\t\t\tmap['ThreadGroup.loops_count'] = 1\n"
    # envstr += "\t\t\tmap['ThreadGroup.num_threads'] = 10\n"
    # envstr += "\t\t\tmap['ThreadGroup.ramp_time'] = 1\n"
    # envstr += "\t\tend\n"
    # envstr += "\tend\n"
    #
    #
    # #cluster configuration
    # envstr += "\n\n\t# EC2 configuration\n"
    # envstr += "\tconfig.clusters(:amazon_cloud) do |cluster|\n"
    # envstr += "\t\tcluster.access_key = 'AKIAI5YQZTSVCML7463Q'\n"
    # envstr += "\t\tcluster.secret_key = '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'\n"
    # envstr += "\t\tcluster.region = 'us-east-1'\n"
    # envstr += "\t\tcluster.instance_type = 'c1.xlarge'\n"
    # envstr += "\tend\n"
    #
    # envstr += "end"
    # #puts envstr
    #
    # File.open(env_file_path, 'w') { |file| file.write(envstr) }
    #
    # #setup database by initializing application
    # app_boot_file_path = File.join(app_directory, 'config/boot.rb')
    # #puts "app boot file path : "+app_boot_file_path
    # Hailstorm::Application.initialize!(app_name,app_boot_file_path)

    #now setup app configuration
    #Hailstorm.application.interpret_command("setup")

    puts "application configuration ended"
  end


end