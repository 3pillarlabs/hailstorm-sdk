# frozen_string_literal: true

include ModelHelper

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

Then(/^installed JMeter version should be '(.+?)'$/) do |expected_jmeter_version|
  require 'hailstorm/support/ssh'
  jmeter_version_out = StringIO.new
  ssh_args = [(@load_agent || @ec2_instance).public_ip_address, @aws.user_name, @aws.ssh_options]
  Hailstorm::Support::SSH.start(*ssh_args) do |ssh|
    ssh.exec!('$HOME/jmeter/bin/jmeter --version') do |_ch, stream, data|
      jmeter_version_out << data if stream == :stdout
    end
  end

  expect(jmeter_version_out.string).to_not be_blank
  expect(jmeter_version_out.string).to include(expected_jmeter_version)
end

Then(/^custom properties should be added$/) do
  require 'hailstorm/support/ssh'
  require 'tmpdir'
  remote_jmeter_props_file = File.join(Dir.tmpdir, 'user.properties')
  Hailstorm::Support::SSH.start(@load_agent.public_ip_address, @aws.user_name, @aws.ssh_options) do |ssh|
    ssh.download("/home/#{@aws.user_name}/jmeter/bin/user.properties", remote_jmeter_props_file)
  end
  remote_jmeter_props = File.readlines(remote_jmeter_props_file).collect(&:chomp)
  expect(remote_jmeter_props).to include('jmeter.save.saveservice.hostname=true')
  expect(remote_jmeter_props).to include('jmeter.save.saveservice.thread_counts=true')
  expect(remote_jmeter_props).to include('jmeter.save.saveservice.output_format=xml')
end
