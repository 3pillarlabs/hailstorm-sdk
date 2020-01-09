# Steps invoked by initializing and calling Hailstorm
include ModelHelper

Given(/^(?:Hailstorm is initialized with a project|the) ['"]([^'"]+)['"](?:| project(?:| is active))$/) do |project_code|
  require 'hailstorm/model/project'
  @project = find_project(project_code)
  require 'hailstorm/support/configuration'
  @hailstorm_config = Hailstorm::Support::Configuration.new
  # TODO provide an implementation for Hailstorm.fs=
end

When(/^the JMeter version for the project is '(.+?)'$/) do |jmeter_version|
  @project.jmeter_version = jmeter_version
end

When(/^(?:the |)[jJ][mM]eter installer URL for the project is '(.+?)'$/) do |jmeter_installer_url|
  @project.jmeter_version = nil
  @project.custom_jmeter_installer_url = jmeter_installer_url
  @project.send(:set_defaults)
end

When(/^(?:I |)configure JMeter with following properties$/) do |table|
  @hailstorm_config.jmeter.properties do |map|
    table.hashes.each { |kvp| map[kvp['property']] = kvp['value'].to_i }
  end
end

When(/^(?:I |)configure following data centers?$/) do |table|
  # table is a table.hashes.keys # => [:title, :user_name, :ssh_identity]
  dc = YAML.load_file(File.join(data_path, 'data-center-machines.yml')).symbolize_keys
  attrs = { machines: dc[:machines], cluster_type: :data_center }
  attrs[:ssh_port] = dc[:ssh_port] if dc.key?(:ssh_port) && dc[:ssh_port]
  table.hashes
      .collect { |e| e.merge(attrs) }
      .each do |dc_attrs|

    # @type [Hailstorm::Support::Configuration] @hailstorm_config
    @hailstorm_config.clusters(:data_center) do |dc|
      dc_attrs.each_pair do |key, value|
        if key.to_sym == :ssh_identity
          value = File.join(data_path, "#{key.gsub(/\.pem$/, '')}.pem")
        end
        dc.send("#{key}=", value)
      end
    end
  end
end

When(/^(?:I |)configure following amazon clusters$/) do |table|
  access_key, secret_key = aws_keys
  table.hashes
      .collect { |e| e.merge(cluster_type: :amazon_cloud, access_key: access_key, secret_key: secret_key) }
      .each do |amz_attrs|

    # @type [Hailstorm::Support::Configuration] @hailstorm_config
    @hailstorm_config.clusters(:amazon_cloud) do |amz|
      amz_attrs.each_pair { |key, value| amz.send("#{key}=", value) }
    end
  end
end

When(/^configure target monitoring$/) do
  pending
end

When(/^(?:I |)setup the project$/) do
  @project.settings_modified = true
  @project.serial_version = 'A'
  @project.setup(config: @hailstorm_config)
end

When(/^(?:I |)start load generation$/) do
  @project.start(config: @hailstorm_config)
end

When /^(?:I |)wait for (\d+) seconds$/ do |wait_seconds|
  sleep(wait_seconds.to_i)
end

When(/^(?:I |)stop load generation with '(.+?)'$/) do |wait|
  @project.stop(wait)
end

When(/^abort the load generation$/) do
  @project.abort
end

When(/^(?:I |)terminate the setup$/) do
  @project.terminate
end

When(/^(?:I |)generate a report$/) do
  @project.results(:report, config: @hailstorm_config)
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

Then(/^(\d+) (active |)load agents? should exist$/) do |expected_load_agent_count, active|
  require 'hailstorm/model/load_agent'
  query = Hailstorm::Model::LoadAgent
  query = query.active if active
  query = query.joins(clusterable: :project).where(project: { id: @project.id })
  expect(query.count).to be == expected_load_agent_count.to_i
end

Then(/^(\d+) Jmeter instances? should be running$/) do |expected_pid_count|
  query = Hailstorm::Model::LoadAgent.active
              .joins(clusterable: :project)
              .where(project: { id: @project.id })
              .where('jmeter_pid IS NOT NULL')
  expect(query.count).to be == expected_pid_count.to_i
end

Then /^(\d+) (total|reportable) execution cycles? should exist$/ do |expected_count, total|
  conditions = { projects: {id: @project.id} }
  conditions.merge!(status: 'stopped') if total.to_sym == :reportable
  expect(Hailstorm::Model::ExecutionCycle.joins(:project).where(conditions).count).to be == expected_count.to_i
end

Then(/^a report file should be created$/) do
  expect(File.exist?(Hailstorm.fs.report_path)).to be_true
end
