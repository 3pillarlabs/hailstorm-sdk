require 'yaml'
require 'socket'
require 'cli_step_helper'

include CliStepHelper

And(/^data center machines are accessible$/) do
  dc = YAML.load_file(File.join(data_path, 'data-center-machines.yml')).symbolize_keys
  dc[:machines].each do |machine|
    host, port = machine.split(':')
    TCPSocket.new(host, port)
  end
end

And(/^configure following data center$/) do |table|
  # table is a table.hashes.keys # => [:title, :user_name, :ssh_identity]
  dc = YAML.load_file(File.join(data_path, 'data-center-machines.yml')).symbolize_keys
  clusters(table.hashes.collect { |e| e.merge(machines: dc[:machines], cluster_type: :data_center) })
  identity_file = File.join(tmp_path, current_project, Hailstorm.config_dir, 'insecure_key')
  unless File.exist?(identity_file)
    FileUtils.cp(File.join(data_path, 'insecure_key'),
                 File.join(tmp_path, current_project, Hailstorm.config_dir))
    File.chmod(0o400, identity_file)
  end
end
