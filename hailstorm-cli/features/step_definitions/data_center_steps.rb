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
  clusters(table
               .hashes
               .collect { |e| e.merge(attrs)
                               .merge(machines: e[:machines].split(/\s*,\s*/))
                               .merge(ssh_identity: File.join(data_path,
                                                              "#{e[:ssh_identity].gsub(/\.pem$/, '')}.pem")) })


end
