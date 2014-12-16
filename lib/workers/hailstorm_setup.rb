require 'sidekiq'
require 'hailstorm/application'
require 'fileutils'

class HailstormSetup
  include Sidekiq::Worker

  def perform(app_name, app_root_path)
    puts "configure application"
    puts "app name : "+app_name
    puts "app root path : "+app_root_path

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
    sourcejmx_file_path = File.join(app_root_path, "testproject5", 'jmeter/ASP_SHOP.jmx')
    destjmx_file_path = File.join(app_directory, 'jmeter/')
    FileUtils.cp(sourcejmx_file_path,destjmx_file_path)

    #create enviroment file for app
    env_file_path = File.join(app_directory, 'config/environment.rb')

    envstr = "# Hailstorm configuration \n"
    envstr += "Hailstorm.application.config do |config|\n"

    #JMeter configuration
    envstr += "\n\n\t# This is the JMeter configuration\n"
    envstr += "\tconfig.jmeter do |jmeter|\n"
    envstr += "\t\tjmeter.properties do |map|\n"
    envstr += "\t\t\tmap['ThreadGroup.loops_count'] = 1\n"
    envstr += "\t\t\tmap['ThreadGroup.num_threads'] = 10\n"
    envstr += "\t\t\tmap['ThreadGroup.ramp_time'] = 1\n"
    envstr += "\t\tend\n"
    envstr += "\tend\n"


    #cluster configuration
    envstr += "\n\n\t# EC2 configuration\n"
    envstr += "\tconfig.clusters(:amazon_cloud) do |cluster|\n"
    envstr += "\t\tcluster.access_key = 'AKIAI5YQZTSVCML7463Q'\n"
    envstr += "\t\tcluster.secret_key = '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'\n"
    envstr += "\t\tcluster.region = 'us-east-1'\n"
    envstr += "\t\tcluster.instance_type = 'c1.xlarge'\n"
    envstr += "\tend\n"

    envstr += "end"
    #puts envstr

    File.open(env_file_path, 'w') { |file| file.write(envstr) }

    #setup database by initializing application
    app_boot_file_path = File.join(app_directory, 'config/boot.rb')
    #puts "app boot file path : "+app_boot_file_path
    Hailstorm::Application.initialize!(app_name,app_boot_file_path)

    #now setup app configuration
    # Hailstorm.application.interpret_command("setup")

    puts "application configuration ended"
  end


end