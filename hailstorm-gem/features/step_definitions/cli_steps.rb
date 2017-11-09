require 'ostruct'
require 'action_view/base'

include CliStepHelper

Given(/^I have [hH]ailstorm installed$/) do
  require 'hailstorm/application'
end

When(/^I created? the project "([^"]*)"$/) do |project_name|
  project_path = File.join(tmp_path, project_name)
  unless File.exists?(project_path)
    Hailstorm::Application.new.create_project(tmp_path, project_name)
  end
end

Then(/^the project structure for "([^"]*)" should be created$/) do |top_folder|
  project_path = File.join(tmp_path, top_folder)
  expect(File).to exist(project_path)
  expect(File).to be_a_directory(File.join(project_path, Hailstorm.db_dir))
  expect(File).to be_a_directory(File.join(project_path, Hailstorm.app_dir))
  expect(File).to be_a_directory(File.join(project_path, Hailstorm.log_dir))
  expect(File).to be_a_directory(File.join(project_path, Hailstorm.tmp_dir))
  expect(File).to be_a_directory(File.join(project_path, Hailstorm.reports_dir))
  expect(File).to be_a_directory(File.join(project_path, Hailstorm.config_dir))
  expect(File).to be_a_directory(File.join(project_path, Hailstorm.vendor_dir))
  expect(File).to be_a_directory(File.join(project_path, Hailstorm.script_dir))
  expect(File).to be_a_directory(project_path)
  expect(File).to be_a_directory(project_path)
  expect(File).to exist(File.join(project_path, 'Gemfile'))
  expect(File).to exist(File.join(project_path, Hailstorm.script_dir, 'hailstorm'))
  expect(File).to exist(File.join(project_path, Hailstorm.config_dir, 'environment.rb'))
  expect(File).to exist(File.join(project_path, Hailstorm.config_dir, 'database.properties'))
  expect(File).to exist(File.join(project_path, Hailstorm.config_dir, 'boot.rb'))
end

When(/^I launch the hailstorm console within "([^"]*)" project$/) do |project_name|
  current_project(project_name)
  write_config(@monitor_active) # reset
  Dir[File.join(tmp_path, project_name, Hailstorm.reports_dir, '*')].each do |file|
    FileUtils.rm(file)
  end
  Hailstorm::Application.initialize!(project_name,
                                     File.join(tmp_path, project_name,
                                               Hailstorm.config_dir, 'boot.rb'))
end

Then(/^the application should be ready to accept commands$/) do
  Hailstorm.application.interpret_command('purge')
  expect(Hailstorm::Model::ExecutionCycle.count).to eql(0)
  expect(Dir[File.join(tmp_path, current_project, Hailstorm.tmp_dir, '*')].count).to eql(0)
  Hailstorm::Model::Project.first.update_attribute(:serial_version, nil)
end

Given(/^the "([^"]*)" project$/) do |project_name|
  current_project(project_name)
end

When(/^(?:I |)configure JMeter with following properties$/) do |table|
  [
      'hailstorm-site-basic.jmx'
  ].each do |test_file|
    file_path = File.join(tmp_path, current_project, Hailstorm.app_dir, test_file)
    unless File.exist? file_path
      FileUtils.cp(File.join(data_path, test_file), file_path)
    end
  end
  jmeter_properties(table.hashes)
end

When(/^(?:I |)configure following amazon clusters$/) do |table|
  clusters(table.hashes.collect { |e| e.merge(cluster_type: :amazon_cloud) })
end

When(/^(?:I |)configure target monitoring$/) do
  identity_file = File.join(tmp_path, current_project, Hailstorm.config_dir, 'all_purpose.pem')
  unless File.exists?(identity_file)
    FileUtils.cp(File.join(data_path, 'all_purpose.pem'),
               File.join(tmp_path, current_project, Hailstorm.config_dir))
    File.chmod(0400, identity_file)
  end
end

When(/^(?:I |)execute "(.*?)" command$/) do |command|
  write_config(@monitor_active) if config_changed?
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

When /^(\d+) (total|reportable) execution cycles? should exist$/ do |expected_count, total|
  if total.to_sym == :reportable
    Hailstorm::Model::ExecutionCycle.where(:status => 'stopped').count.should == expected_count.to_i
  else
    Hailstorm::Model::ExecutionCycle.count.should == expected_count.to_i
  end
end

Then /^a report file should be created$/ do
  Dir[File.join(tmp_path, current_project, Hailstorm.reports_dir, '*.docx')].count.should == 1
end


And(/^results import '(.+?)'$/) do |file_path|
  Hailstorm.application.interpret_command('purge')
  expect(Hailstorm::Model::ExecutionCycle.count).to eql(0)
  abs_path = File.expand_path(file_path, __FILE__)
  Hailstorm.application.interpret_command("results import #{abs_path}")
  expect(Hailstorm::Model::ExecutionCycle.count).to eql(1)
end


And(/^(?:disable |)target monitoring(?:| is disabled)$/) do
  @monitor_active = false
end