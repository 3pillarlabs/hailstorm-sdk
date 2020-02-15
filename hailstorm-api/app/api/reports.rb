require 'sinatra'
require 'json'
require 'db/seed'

get '/projects/:project_id/reports' do |project_id|
  sleep 0.4
  JSON.dump(Seed::DB[:reports].select { |r|  r[:projectId] == project_id.to_s.to_i })
end

post '/projects/:project_id/reports' do |project_id|
  sleep 3
  project = Seed::DB[:projects].find { |p| p[:id] == project_id.to_s.to_i }
  return 404 unless project

  request.body.rewind
  data = JSON.parse(request.body.read).sort
  first_x_cid, last_x_cide = data[0], data[-1]
  title = "#{project[:code]}-#{first_x_cid}-#{last_x_cide}"
  report = { id: Seed::DB[:sys][:report_idx].call, projectId: project_id.to_s.to_i, title: title }
  Seed::DB[:reports].push(report)
  JSON.dump(report)
end