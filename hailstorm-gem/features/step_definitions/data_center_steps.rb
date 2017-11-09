require 'yaml'
require 'socket'

include CliStepHelper

And(/^(\d+) data center machines are accessible$/) do |machines_count|
  dc = YAML.load_file(File.join(data_path, 'data-center-machines.yml')).symbolize_keys
  machines = dc[:machines]
  expect(machines.length).to eql(machines_count.to_i)
  machines.each do |machine|
    host, port = machine.split(':')
    port ||= 22
    TCPSocket.new(host, port)
  end
end

And(/^configure following data center$/) do |table|
  # table is a table.hashes.keys # => [:title, :user_name, :ssh_identity]
  dc = YAML.load_file(File.join(data_path, 'data-center-machines.yml')).symbolize_keys
  clusters(table.hashes.collect { |e| e.merge(machines: dc[:machines], cluster_type: :data_center) })
  table.hashes.collect { |e| e[:ssh_identity] }.each do |identity|
    identity_file = File.join(tmp_path, current_project, Hailstorm.config_dir, "#{identity.gsub(/\.pem$/, '')}.pem")
    next if File.exist?(identity_file)
    FileUtils.cp(File.join(data_path, identity), identity_file)
    File.chmod(0o400, identity_file)
  end
end
