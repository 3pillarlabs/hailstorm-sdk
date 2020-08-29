require 'spec_helper'
require 'json'
require 'app/api/jmeter_validations'

describe 'api/jmeter_validations' do
  before(:each) do
    @browser = Rack::Test::Session.new(Sinatra::Application)
  end

  context 'POST /jmeter_validations' do
    it 'should extract properties' do
      allow(Hailstorm.fs).to receive(:fetch_file).and_return(File.expand_path('../../resources/hailstorm-site-basic.jmx', __FILE__))
      project = Hailstorm::Model::Project.create!(project_code: 'api_jmeter_validations_spec')
      params = {
        name: 'hailstorm-site-basic.jmx',
        path: '49247866b7221e512030dea9f101c1e17d4df120',
        projectId: project.id
      }

      @browser.post('/jmeter_validations', JSON.dump(params))
      expect(@browser.last_response).to be_ok
      res = JSON.parse(@browser.last_response.body)
      expect(res.keys).to include('properties')
      expect(res.keys).to include('autoStop')
      expect(res.keys).to include('name')
      expect(res.keys).to include('path')
      expect(res['properties']).to be_an(Array)
      expect(res['properties'][0]).to eq(['NumUsers', nil])
      expect(res['properties'][1]).to eq(%W[RampUp 0])
      expect(res['properties'][2]).to eq(['Duration', nil])
      expect(res['properties'][4]).to eq(%W[ServerName ServerName])
    end

    context 'on validation failure' do
      it 'should respond with validation messages' do
        path = File.expand_path('../../resources/without-simple-writer.jmx', __FILE__)
        allow(Hailstorm.fs).to receive(:fetch_file).and_return(path)

        project = Hailstorm::Model::Project.create!(project_code: 'api_jmeter_validations_spec')
        params = {
          name: 'hailstorm-site-basic.jmx',
          path: '49247866b7221e512030dea9f101c1e17d4df120',
          projectId: project.id
        }

        @browser.post('/jmeter_validations', JSON.dump(params))
        expect(@browser.last_response).to_not be_ok
        res = JSON.parse(@browser.last_response.body).symbolize_keys
        expect(res).to have_key(:validationErrors)
      end
    end
  end
end
