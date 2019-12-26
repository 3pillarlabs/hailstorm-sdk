require 'sinatra'
require 'json'

post '/jmeter_validations' do
  sleep 0.5
  request.body.rewind
  # @type [Hash]
  data = JSON.parse(request.body.read)
  response_data = Hash.new(data)
  response_data['properties'] = [
      ["ThreadGroup.Admin.NumThreads", nil],
      ["ThreadGroup.Users.NumThreads", nil],
      ["Users.RampupTime", nil]
  ]
  response_data['autoStop'] = Time.now.to_i % 2 == 0
  JSON.dump(response_data)
end