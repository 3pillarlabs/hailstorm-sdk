# frozen_string_literal: true

require 'spec_helper'
require 'api/jtl_exports'

describe 'api/jtl_exports' do

  context 'POST /projects/:project_id/jtl_exports' do
    it 'should export results' do
      project = Hailstorm::Model::Project.create!(project_code: 'jtl_exports_spec')
      attrs = { url: "http://hailstorm.webfs/#{project.project_code}/123456/a.jtl", title: 'a.jtl' }
      allow_any_instance_of(Hailstorm::Model::Project).to receive(:results).and_return(attrs)

      browser = Rack::Test::Session.new(Sinatra::Application)
      browser.post("/projects/#{project.id}/jtl_exports", JSON.dump([1, 2, 3]))
      expect(browser.last_response).to be_successful
      expect(JSON.parse(browser.last_response.body).keys.sort).to eq(%w[title url].sort)
    end
  end
end
