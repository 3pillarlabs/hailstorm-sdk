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
  response.headers["Access-Control-Allow-Origin"] = "*"
  response.headers["Access-Control-Allow-Methods"] = "GET, PUT, POST, DELETE, PATCH, OPTIONS"
  response.headers["Access-Control-Allow-Headers"] = "Content-Type, Accept"
  200
end

get "/" do
  JSON.dump(%W[/projects /execution_cycles])
end

require 'api/projects'
require 'api/execution_cycles'
require 'api/reports'
require 'api/jtl_exports'
require 'api/jmeter_plans'
require 'api/jmeter_validations'
