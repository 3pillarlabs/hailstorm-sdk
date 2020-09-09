# frozen_string_literal: true

Before('@aws') do
  $delete_vpc_once ||= false # rubocop: disable Style/GlobalVars
  unless $delete_vpc_once # rubocop: disable Style/GlobalVars
    delete_vpc_if_exists('hailstorm_cli_integration', 'us-east-2')
    $delete_vpc_once = true # rubocop: disable Style/GlobalVars
  end
end


Given(/^the "([^"]+)" command line processor is ready$/) do |app_name|
  require 'hailstorm/initializer'
  require 'hailstorm/controller/cli'
  Hailstorm::Initializer.create_middleware(app_name, File.join(tmp_path, app_name, 'config', 'boot.rb'))
  @cli = Hailstorm::Controller::Cli.new(Hailstorm.application)
  @current_project = app_name
end


Given(/^I have a log file on the local filesystem$/) do
  expect(Dir["#{data_path}/*.jtl"].count).to be_positive
end


When(/^I import results(?: from '([^']+)'|)$/) do |paths|
  write_config(monitor_active: @monitor_active) if config_changed?
  if paths
    cmd_args = paths.split(/\s*,\s*/).map { |p| File.join(data_path, p) }.join(' ')
    @cli.process_cmd_line("results import #{cmd_args}")
  else
    @cli.process_cmd_line('results import')
  end
end


When(/^I copy '([^']+)' to default import directory$/) do |file_names|
  results_import_path = File.join(tmp_path, Hailstorm.app_name, Hailstorm.results_import_dir)
  FileUtils.mkdir_p(results_import_path)
  file_names.split(/\s*,\s*/).each do |file_name|
    FileUtils.cp(File.join(data_path, file_name), File.join(results_import_path, file_name))
  end
end


Then(/^(\d+) log files? should be imported$/) do |expected_logs_count|
  require 'hailstorm/model/client_stat'
  expect(Hailstorm::Model::ClientStat
             .joins(execution_cycle: :project)
             .where(projects: { id: @cli.current_project.id }).count).to be == expected_logs_count.to_i
end


When(/^I generate a report$/) do
  @cli.process_cmd_line('results report')
end


When(/^(?:I |)(capture the output of|execute) the command "([^"]*)"$/) do |capture_execute, command|
  if capture_execute =~ /capture/
    @last_cmd_out = capture_cmd_output { @cli.process_cmd_line(command) }
    log(@last_cmd_out)
  else
    @cli.process_cmd_line(command)
  end
end


Then(/^output should( not|) be shown(?:\s+matching "([^"]+)"|)$/) do |negate, content|
  if content
    expect(@last_cmd_out).to match(Regexp.new(content)) if negate.blank?
    expect(@last_cmd_out).to_not match(Regexp.new(content)) unless negate.blank?
  else
    expect(@last_cmd_out).to_not be_blank
  end
end


And(/^finalize the configuration$/) do
  write_config(monitor_active: @monitor_active)
end


When(/^(?:I |)start load generation$/) do
  @cli.process_cmd_line('start')
end


When(/^(?:I |)stop load generation with '(.+?)'$/) do |wait|
  @cli.process_cmd_line(wait.blank? ? 'stop' : 'stop wait')
end


When(/^(?:I |)abort the load generation$/) do
  @cli.process_cmd_line('abort')
end


When(/^(?:I |)terminate the setup$/) do
  @cli.process_cmd_line('terminate')
end


When(/^(?:I |)wait for load generation to stop$/) do
  sleep(60)
  @cli.process_cmd_line('stop wait')
end


When(/^(?:I |)configure JMeter with following properties$/) do |table|
  [
    'hailstorm-site-basic.jmx'
  ].each do |test_file|
    file_path = File.join(tmp_path, current_project, Hailstorm.app_dir, test_file)
    FileUtils.cp(File.join(data_path, test_file), file_path) unless File.exist?(file_path)
  end
  jmeter_properties(table.hashes)
end


When(/^(?:I |)configure following amazon clusters$/) do |table|
  clusters(table.hashes.collect { |e| e.merge(cluster_type: :amazon_cloud) })
end


When(/^(?:I |)configure target monitoring$/) do
  identity_file = File.join(tmp_path, current_project, Hailstorm.config_dir, 'all_purpose.pem')
  unless File.exist?(identity_file)
    FileUtils.cp(File.join(data_path, 'all_purpose.pem'),
                 File.join(tmp_path, current_project, Hailstorm.config_dir))
    File.chmod(0o400, identity_file)
  end
end


Then(/^(\d+) (active |)load agents? should exist$/) do |expected_load_agent_count, active|
  project = Hailstorm::Model::Project.find_by_project_code(@current_project)
  conditions = { projects: { id: project.id } }
  conditions[:load_agents] = { active: true } unless active.blank?
  query = Hailstorm::Model::LoadAgent.joins(jmeter_plan: :project).where(conditions)
  expect(query.count).to be == expected_load_agent_count.to_i
end


Then(/^(\d+) Jmeter instances? should be running$/) do |expected_pid_count|
  project = Hailstorm::Model::Project.find_by_project_code(@current_project)
  query = Hailstorm::Model::LoadAgent
          .active
          .joins(jmeter_plan: :project)
          .where(projects: { id: project.id })
          .where('load_agents.jmeter_pid IS NOT NULL')

  expect(query.count).to be == expected_pid_count.to_i
end


When(/^(?:I |)wait for (\d+) seconds$/) do |wait_seconds|
  sleep(wait_seconds.to_i)
end


When(/^(\d+) (total|reportable) execution cycles? should exist$/) do |expected_count, total|
  project = Hailstorm::Model::Project.find_by_project_code(@current_project)
  conditions = { projects: { id: project.id } }
  conditions[:execution_cycles] = { status: 'stopped' } if total.to_sym == :reportable
  query = Hailstorm::Model::ExecutionCycle.joins(:project).where(conditions)
  expect(query.count).to be == expected_count.to_i
end


Then(/^a report file should be created$/) do
  expect(Dir[File.join(tmp_path, current_project, Hailstorm.reports_dir, '*.docx')].count).to be_positive
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


When(/^(?:I |)setup the project$/) do
  @cli.process_cmd_line('setup')
end
