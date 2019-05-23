require 'yaml'
require 'socket'

And(/^(\d+) data center machines are accessible$/) do |machines_count|
  dc = YAML.load_file(File.join(data_path, 'data-center-machines.yml')).symbolize_keys
  machines = dc[:machines]
  port = dc.key?(:ssh_port) && dc[:ssh_port] ? dc[:ssh_port] : 22
  expect(machines.length).to eql(machines_count.to_i)
  machines.each do |host|
    TCPSocket.new(host, port)
  end
end
