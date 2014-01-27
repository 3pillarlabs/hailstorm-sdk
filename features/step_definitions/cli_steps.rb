require 'ostruct'
require 'action_view/base'

module CliStepHelper
  def tmp_path
    File.expand_path('../../../tmp', __FILE__)
  end

  def data_path
    File.expand_path('../../data', __FILE__)
  end

  def current_project(new_project = nil)
    @current_project ||= new_project
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
        s.cluster_type = :amazon_cloud
        s.access_key = keys.access_key if s.access_key.nil?
        s.secret_key = keys.secret_key if s.secret_key.nil?
        s
      end
      @config_changed = true
    end
    @clusters || []
  end

  def config_changed?
    @config_changed
  end

  def write_config
    engine = ActionView::Base.new
    engine.assign(:properties => jmeter_properties,
                  :clusters => clusters)
    File.open(File.join(tmp_path, current_project,
                        Hailstorm.config_dir, 'environment.rb'), 'w') do |env_file|
      env_file.print(engine.render(:file => File.join(data_path, 'environment')))
    end
    @config_changed = false
  end

end

include CliStepHelper

Given(/^I have hailstorm installed$/) do
  require 'hailstorm/application'
end

When(/^I create the project "([^"]*)"$/) do |project_name|
  project_path = File.join(tmp_path, project_name)
  unless File.exists?(project_path)
    Hailstorm::Application.new.create_project(tmp_path, project_name)
  end
end

Then(/^the project structure for "([^"]*)" should be created$/) do |top_folder|
  project_path = File.join(tmp_path, top_folder)
  conditions = File.exists?(project_path) &&
      File.directory?(project_path) &&
      File.directory?(File.join(project_path, Hailstorm.db_dir)) &&
      File.directory?(File.join(project_path, Hailstorm.app_dir)) &&
      File.directory?(File.join(project_path, Hailstorm.log_dir)) &&
      File.directory?(File.join(project_path, Hailstorm.tmp_dir)) &&
      File.directory?(File.join(project_path, Hailstorm.reports_dir)) &&
      File.directory?(File.join(project_path, Hailstorm.config_dir)) &&
      File.directory?(File.join(project_path, Hailstorm.vendor_dir)) &&
      File.directory?(File.join(project_path, Hailstorm.script_dir)) &&
      File.exists?(File.join(project_path, 'Gemfile')) &&
      File.exists?(File.join(project_path, Hailstorm.script_dir, 'hailstorm')) &&
      File.exists?(File.join(project_path, Hailstorm.config_dir, 'environment.rb')) &&
      File.exists?(File.join(project_path, Hailstorm.config_dir, 'database.properties')) &&
      File.exists?(File.join(project_path, Hailstorm.config_dir, 'boot.rb'))

  conditions.should be_true
end

When(/^I launch the hailstorm console within "([^"]*)" project$/) do |project_name|
  current_project(project_name)
  write_config # reset
  Dir[File.join(tmp_path, project_name, Hailstorm.reports_dir, '*')].each do |file|
    FileUtils.rm(file)
  end
  Hailstorm::Application.initialize!(project_name,
                                     File.join(tmp_path, project_name,
                                               Hailstorm.config_dir, 'boot.rb'))
end

Then(/^the application should be ready to accept commands$/) do
  Hailstorm.application.interpret_command('purge')
  Hailstorm::Model::ExecutionCycle.count.should == 0
  Dir[File.join(tmp_path, current_project, Hailstorm.tmp_dir, '*')].count.should == 0
  Hailstorm::Model::Project.first.update_attribute(:serial_version, nil)
end

Given(/^the "([^"]*)" project$/) do |project_name|
  current_project(project_name)
end

When(/^(?:I |)configure JMeter with following properties$/) do |table|
  jmx_file_path = File.join(tmp_path, current_project, Hailstorm.app_dir, 'TestDroidLogin.jmx')
  unless File.exists? jmx_file_path
    FileUtils.cp(File.join(data_path, 'TestDroidLogin.jmx'), jmx_file_path)
  end
  data_file_path = File.join(tmp_path, current_project, Hailstorm.app_dir, 'testdroid_accounts.csv')
  unless File.exists? data_file_path
    FileUtils.cp(File.join(data_path, 'testdroid_accounts.csv'), data_file_path)
  end

  jmeter_properties(table.hashes)
end

When(/^(?:I |)configure following amazon clusters$/) do |table|
  clusters(table.hashes)
end

When(/^(?:I |)configure target monitoring$/) do
  identity_file = File.join(tmp_path, current_project, Hailstorm.db_dir,
                             'testroid_identity.pem')
  unless File.exists?(identity_file)
    FileUtils.cp(File.join(data_path, 'testroid_identity.pem'),
               File.join(tmp_path, current_project, Hailstorm.db_dir))
    File.chmod(0400, identity_file)
  end
end

When(/^(?:I |)execute "(.*?)" command$/) do |command|
  write_config if config_changed?
  Hailstorm.application.interpret_command(command)
end

Then(/^(\d+) (active |)load agents? should exist$/) do |expected_load_agent_count, active|
  if active.blank?
    Hailstorm::Model::LoadAgent.count.should == expected_load_agent_count.to_i
  else
    Hailstorm::Model::LoadAgent.active.count.should == expected_load_agent_count.to_i
  end
end

Then(/^(\d+) Jmeter instances? should be running$/) do |expected_pid_count|
  Hailstorm::Model::LoadAgent.active.where('jmeter_pid IS NOT NULL').count.should == expected_pid_count.to_i
end

When /^(?:I |)wait for (\d+) seconds$/ do |wait_seconds|
  sleep(wait_seconds.to_i)
end

When /^(\d+) (total|reportable) execution cycles should exist$/ do |expected_count, total|
  if total.to_sym == :reportable
    Hailstorm::Model::ExecutionCycle.where(:status => 'stopped').count.should == expected_count.to_i
  else
    Hailstorm::Model::ExecutionCycle.count.should == expected_count.to_i
  end
end

Then /^a report file should be created$/ do
  Dir[File.join(tmp_path, current_project, Hailstorm.reports_dir, '*.docx')].count.should == 1
end