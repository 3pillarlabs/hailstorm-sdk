require 'spec_helper'

describe 'initializer/api_config' do
  before(:each) do
    @browser = Rack::Test::Session.new(Sinatra::Application)
  end

  it 'should fetch version' do
    @browser.get('/')
    expect(@browser.last_response).to be_ok
    json_data = JSON.parse(@browser.last_response.body)
    expect(json_data.keys).to include('version')
  end

  it 'should fetch options' do
    @browser.options('/')
    expect(@browser.last_response).to be_ok
  end
end
