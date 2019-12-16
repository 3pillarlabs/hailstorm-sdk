require 'sinatra'
require 'json'
require 'config/db/seed'

get '/projects' do
  JSON.dump(Seed::DB[:projects].map { |project|
    project[:currentExecutionCycle] = Seed::DB[:executionCycles]
                                          .find { |x| x[:projectId] == project[:id] && x[:stoppedAt].nil? }
    project
  })
end
