# frozen_string_literal: true

require 'socket'

And(/^data center machines are accessible$/) do |table|
  # table is a table.hashes.keys # => [:host]
  table.hashes.each do |map|
    host = map[:host]
    expect { TCPSocket.new(host, 22) }.to_not raise_error
  end
end


When(/^(?:I |)configure following data centers?$/) do |table|
  # table is a table.hashes.keys # => [:title, :user_name, :ssh_identity, :machines]
  attrs = { cluster_type: :data_center, ssh_port: 22 }
  to_attributes = proc do |table_attrs|
    table_attrs
      .merge(attrs)
      .merge(machines: table_attrs[:machines].split(/\s*,\s*/))
      .merge(ssh_identity: File.join(data_path, "#{table_attrs[:ssh_identity].gsub(/\.pem$/, '')}.pem"))
  end
  clusters(table.hashes.collect { |e| to_attributes.call(e) })
end
