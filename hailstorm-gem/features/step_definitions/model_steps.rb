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
  fs = Object.new.extend(Hailstorm::Behavior::FileStore)
  class << fs
    JMX_PATH = File.expand_path('../../data/hailstorm-site-basic.jmx', __FILE__)

    attr_writer :jtl_path
    attr_reader :report_path

    def fetch_jmeter_plans(*_args)
      ['hailstorm-site-basic']
    end

    def app_dir_tree(*_args)
      { data: nil }.stringify_keys
    end

    def transfer_jmeter_artifacts(_project_code, to_dir_path)
      FileUtils.cp(JMX_PATH, "#{to_dir_path}/hailstorm-site-basic.jmx")
    end

    def copy_jtl(_project_code, from_path:, to_path:)
      jtl_file = File.basename(@jtl_path)
      copied_path = "#{to_path}/#{jtl_file}"
      FileUtils.cp(@jtl_path, copied_path)
      copied_path
    end

    def export_report(_project_code, local_path)
      file_name = File.basename(local_path)
      export_path = File.expand_path('../../../build', __FILE__)
      @report_path = File.join(export_path, file_name)
      FileUtils.cp(local_path, @report_path)
    end
  end

  fs.jtl_path = abs_jtl_path
  Hailstorm.fs = fs
  require 'hailstorm/middleware/command_execution_template'
  template = Hailstorm::Middleware::CommandExecutionTemplate.new(@project, @hailstorm_config)
  template.results(false, nil, :import, [[abs_jtl_path], nil])
end
