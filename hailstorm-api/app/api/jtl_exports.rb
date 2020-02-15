require 'sinatra'
require 'json'
require 'db/seed'

post '/projects/:project_id/jtl_exports' do |project_id|
  sleep 3
  project = Seed::DB[:projects].find { |p| p[:id] == project_id.to_s.to_i }
  return 404 unless project

  request.body.rewind
  # @type [Array]
  data = JSON.parse(request.body.read).sort
  first_x_cid, last_x_cid = data.length > 1 ? [data[0], data[-1]] : [data[0], nil]
  title = "#{project[:code]}-#{first_x_cid}"
  title += "-#{last_x_cid}" if last_x_cid
  file_extn = last_x_cid ? 'zip' : 'jtl'
  file_name = "#{title}.#{file_extn}"
  JSON.dump({ title: file_name, url: "http://static.hailstorm.local/#{file_name}"})
end