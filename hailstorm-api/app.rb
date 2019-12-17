require 'bundler/setup'

require 'active_record'
require 'config/db/migrations'

require 'sinatra'

before do
  response.headers['Access-Control-Allow-Origin'] = "*"
end

after do
  content_type :json
end

options "*" do
  response.headers["Allow"] = "GET, PUT, POST, DELETE, OPTIONS"
  response.headers["Access-Control-Allow-Headers"] = "Authorization, Content-Type, Accept, X-User-Email, X-Auth-Token"
  response.headers["Access-Control-Allow-Origin"] = "*"
  200
end

get "/" do
  JSON.dump(%W[/projects])
end

require 'api/projects'
