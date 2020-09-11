# frozen_string_literal: true

require 'spec_helper'
require 'api/jmeter_plans'

describe 'api/jmeter_plans' do

  before(:each) do
    @browser = Rack::Test::Session.new(Sinatra::Application)
  end

  context 'POST /projects/:project_id/jmeter_plans' do
    it 'should add test plan to project configuration' do
      project = Hailstorm::Model::Project.create!(project_code: 'api_jmeter_plans_spec')
      params = {
        name: 'hailstorm.jmx',
        path: '1234',
        properties: [
          %w[NumUsers 10],
          %w[RampUp 30],
          %w[Duration 180],
          %w[ServerName 152.36.34.28]
        ]
      }

      @browser.post("/projects/#{project.id}/jmeter_plans", JSON.dump(params))
      expect(@browser.last_response).to be_ok
      res = JSON.parse(@browser.last_response.body)
      expect(res.keys).to include('id')
      expect(ProjectConfiguration.where(project_id: project.id).first).to_not be_nil
    end

    it 'should add data file' do
      project = Hailstorm::Model::Project.create!(project_code: 'api_jmeter_plans_spec')
      params = {
        name: 'data.csv',
        path: '1234',
        dataFile: true
      }

      @browser.post("/projects/#{project.id}/jmeter_plans", JSON.dump(params))
      expect(@browser.last_response).to be_ok
      res = JSON.parse(@browser.last_response.body)
      expect(res.keys).to include('id')
      expect(ProjectConfiguration.where(project_id: project.id).first).to_not be_nil
    end
  end

  context 'GET /projects/:project_id/jmeter_plans' do
    it 'should fetch list of JMeter plans' do
      project = Hailstorm::Model::Project.create!(project_code: 'api_jmeter_plans_spec')
      hailstorm_config = Hailstorm::Support::Configuration.new
      hailstorm_config.jmeter do |jmeter|
        jmeter.add_test_plan('123/a.jmx')
        jmeter.properties(test_plan: '123/a.jmx') do |map|
          map['NumUsers'] = '100'
        end

        jmeter.data_files = %w[234/foo.csv]
      end

      ProjectConfiguration.create!(project_id: project.id, stringified_config: deep_encode(hailstorm_config))

      @browser.get("/projects/#{project.id}/jmeter_plans")
      expect(@browser.last_response).to be_ok
      # @type [Array] res
      res = JSON.parse(@browser.last_response.body)
      expect(res.size).to eq(2)
      jmeter_plan = res.first.symbolize_keys
      expect(jmeter_plan[:id]).to_not be_nil
      expect(jmeter_plan[:name]).to eq('a.jmx')
      expect(jmeter_plan[:path]).to eq('123')
      expect(jmeter_plan[:properties]).to eq([%w[NumUsers 100]])

      data_file = res.second.symbolize_keys
      expect(data_file[:id]).to_not be_nil
      expect(data_file[:name]).to eq('foo.csv')
      expect(data_file[:path]).to eq('234')
      expect(data_file[:dataFile]).to be true
    end
  end

  context 'PATCH /projects/:project_id/jmeter_plans/:id' do
    it 'should update the attributes' do
      project = Hailstorm::Model::Project.create!(project_code: 'api_jmeter_plans_spec')
      params = {
        name: 'hailstorm.jmx',
        path: '1234',
        properties: [
          %w[NumUsers 10],
          %w[RampUp 30],
          %w[Duration 180],
          %w[ServerName 152.36.34.28]
        ]
      }

      @browser.post("/projects/#{project.id}/jmeter_plans", JSON.dump(params))
      expect(@browser.last_response).to be_ok
      post_res = JSON.parse(@browser.last_response.body).symbolize_keys

      patch_params = {
        properties: [
          %w[NumUsers 100],
          %w[RampUp 300],
          %w[Duration 1800],
          %w[ServerName 152.36.34.28]
        ]
      }

      @browser.patch("/projects/#{project.id}/jmeter_plans/#{post_res[:id]}", JSON.dump(patch_params))
      expect(@browser.last_response).to be_ok
      patch_res = JSON.parse(@browser.last_response.body).symbolize_keys
      expect(patch_res.keys.sort).to eq(%i[name path properties id].sort)
      expect(patch_res[:id]).to eq(post_res[:id])
      expect(patch_res[:properties].to_h).to eq(patch_params[:properties].to_h)
    end
  end

  context 'DELETE /projects/:project_id/jmeter_plans/:id' do
    it 'should delete a plan' do
      project = Hailstorm::Model::Project.create!(project_code: 'api_jmeter_plans_spec')
      hailstorm_config = Hailstorm::Support::Configuration.new
      hailstorm_config.jmeter do |jmeter|
        jmeter.add_test_plan('1/a.jmx')
        jmeter.properties(test_plan: '1/a.jmx') do |map|
          map['NumUsers'] = 100
        end

        jmeter.add_test_plan('2/b.jmx')
        jmeter.properties(test_plan: '2/b.jmx') do |map|
          map['NumUsers'] = 50
        end

        jmeter.add_test_plan('3/c.jmx')
        jmeter.properties(test_plan: '3/c.jmx') do |map|
          map['NumUsers'] = 25
        end
      end

      project_config = ProjectConfiguration.create!(
        project_id: project.id,
        stringified_config: deep_encode(hailstorm_config)
      )

      id = '2/b'.to_java_string.hash_code
      @browser.delete("/projects/#{project.id}/jmeter_plans/#{id}")
      expect(@browser.last_response).to be_successful
      project_config.reload
      updated_hailstorm_config = deep_decode(project_config.stringified_config)
      expect(updated_hailstorm_config.jmeter.test_plans.size).to eq(2)
      expect(updated_hailstorm_config.jmeter.test_plans.first).to eq('1/a')
      expect(updated_hailstorm_config.jmeter.test_plans.second).to eq('3/c')
    end

    it 'should delete a data file' do
      project = Hailstorm::Model::Project.create!(project_code: 'api_jmeter_plans_spec')
      hailstorm_config = Hailstorm::Support::Configuration.new
      hailstorm_config.jmeter do |jmeter|
        jmeter.add_test_plan('1/a.jmx')
        jmeter.properties(test_plan: '1/a.jmx') do |map|
          map['NumUsers'] = 100
        end

        jmeter.data_files.push('2/a.csv')
      end

      project_config = ProjectConfiguration.create!(
        project_id: project.id,
        stringified_config: deep_encode(hailstorm_config)
      )

      id = '2/a.csv'.to_java_string.hash_code
      @browser.delete("/projects/#{project.id}/jmeter_plans/#{id}")
      expect(@browser.last_response).to be_successful
      project_config.reload
      updated_hailstorm_config = deep_decode(project_config.stringified_config)
      expect(updated_hailstorm_config.jmeter.test_plans.size).to eq(1)
      expect(updated_hailstorm_config.jmeter.data_files.size).to eq(0)
    end
  end
end
