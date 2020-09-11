# frozen_string_literal: true

require 'spec_helper'
require 'api/aws_regions'

describe 'api/aws_regions' do
  before(:each) do
    @browser = Rack::Test::Session.new(Sinatra::Application)
  end

  context 'GET /aws_regions' do
    it 'should fetch regions and default region' do
      @browser.get('/aws_regions')
      expect(@browser.last_response).to be_ok
      json_data = JSON.parse(@browser.last_response.body)
      expect(json_data.keys.sort).to eq(%w[regions defaultRegion].sort)
    end
  end
end
