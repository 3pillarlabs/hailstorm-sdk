require 'spec_helper'
require 'api/reports'
require 'hailstorm/support/configuration'

describe 'api/reports' do
  before(:each) do
    @browser = Rack::Test::Session.new(Sinatra::Application)
  end

  context 'GET /projects/:project_id/reports' do
    it 'should fetch reports from file server' do
      project = Hailstorm::Model::Project.create(project_code: 'reports_spec')
      Hailstorm.fs.stub!(:fetch_reports)
        .and_return(
          [
            { id: 1234, title: 'a.docx', url: 'http://hailstorm.webfs:9000/reports/reports_spec/1234/a.docx' }
          ]
        )

      @browser.get("/projects/#{project.id}/reports")
      expect(@browser.last_response).to be_successful
      data = JSON.parse(@browser.last_response.body)
      expect(data.size).to be == 1
      expect(data[0].keys.sort).to eq(%w[id title url projectId].sort)
    end
  end

  context 'POST /projects/:project_id/reports' do
    it 'should generate the report' do
      project = Hailstorm::Model::Project.create(project_code: 'reports_spec')
      hailstorm_config = Hailstorm::Support::Configuration.new
      ProjectConfiguration.create!(project: project,
                                   stringified_config: deep_encode(hailstorm_config))

      Hailstorm::Model::Project
        .any_instance
        .stub(:results)
        .and_return(
          %w[http://hailstorm.webfs:9000/reports/reports_spec/1234/a.docx 1234]
        )

      @browser.post("/projects/#{project.id}/reports", JSON.dump([1, 2, 3]))
      expect(@browser.last_response).to be_successful
      data = JSON.parse(@browser.last_response.body)
      expect(data.keys).to eq(%W[id projectId title uri])
      expect(data['title']).to be == 'a.docx'
    end
  end
end
