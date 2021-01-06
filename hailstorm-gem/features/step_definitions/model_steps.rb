# frozen_string_literal: true

# Steps invoked by initializing and calling Hailstorm
include ModelHelper

Given(/^(?:Hailstorm is initialized with a project|the) ['"]([^'"]+)['"](?:| project(?:| is active))$/) do |project_code|
  require 'hailstorm/model/project'
  @project = find_project(project_code)
  require 'hailstorm/support/configuration'
  @hailstorm_config = Hailstorm::Support::Configuration.new
end

When(/^the JMeter version for the project is '(.+?)'$/) do |jmeter_version|
  @project.jmeter_version = jmeter_version
end

When(/^(?:the |)[jJ][mM]eter installer URL for the project is '(.+?)'$/) do |jmeter_installer_url|
  @project.jmeter_version = nil
  @project.custom_jmeter_installer_url = jmeter_installer_url
  @project.send(:set_defaults)
end

When(/^import results from '(.+)'$/) do |jtl_path|
  abs_jtl_path = File.expand_path(jtl_path, __FILE__)
  @project.settings_modified = true
  require 'hailstorm/behavior/file_store'
  fs = CukeDataFs.new
  fs.jtl_path = abs_jtl_path
  Hailstorm.fs = fs
  require 'hailstorm/middleware/command_execution_template'
  template = Hailstorm::Middleware::CommandExecutionTemplate.new(@project, @hailstorm_config)
  template.results(false, nil, :import, [[abs_jtl_path], nil])
end
