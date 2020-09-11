# frozen_string_literal: true

require 'spec_helper'

require 'api/load_agents'
require 'hailstorm/model/project'
require 'hailstorm/model/cluster'
require 'hailstorm/model/amazon_cloud'
require 'hailstorm/model/jmeter_plan'
require 'hailstorm/model/master_agent'

describe 'api/load_agents' do

  context 'GET /projects/:project_id/load_agents' do
    it 'should return all load agents for a project' do
      project = Hailstorm::Model::Project.create!(project_code: 'load_agents_spec')
      us_east_amz = Hailstorm::Model::AmazonCloud.create!(
        project: project,
        access_key: 'A',
        secret_key: 'a',
        vpc_subnet_id: 'subnet-123',
        active: false,
        region: 'us-east-1'
      )

      us_east_amz.update_column(:active, true)
      Hailstorm::Model::Cluster.create!(
        project: project,
        cluster_type: us_east_amz.class.name,
        clusterable_id: us_east_amz.id
      )

      us_west_amz = Hailstorm::Model::AmazonCloud.create!(
        project: project,
        access_key: 'A',
        secret_key: 'a',
        vpc_subnet_id: 'subnet-123',
        active: false,
        region: 'us-west-1'
      )

      us_west_amz.update_column(:active, true)
      Hailstorm::Model::Cluster.create!(
        project: project,
        cluster_type: us_west_amz.class.name,
        clusterable_id: us_west_amz.id
      )

      shopping_jmeter_plan = Hailstorm::Model::JmeterPlan.create!(
        project: project,
        test_plan_name: 'shopping_cart',
        content_hash: 'A',
        active: false,
        properties: '{}'
      )

      shopping_jmeter_plan.update_column(:active, true)
      listing_jmeter_plan = Hailstorm::Model::JmeterPlan.create!(
        project: project,
        test_plan_name: 'listing',
        content_hash: 'A',
        active: false,
        properties: '{}'
      )

      listing_jmeter_plan.update_column(:active, true)

      [us_east_amz, us_west_amz].each do |clusterable|
        [shopping_jmeter_plan, listing_jmeter_plan].each_with_index do |jmeter_plan, index|
          Hailstorm::Model::MasterAgent.create!(
            clusterable_id: clusterable.id,
            clusterable_type: clusterable.class.name,
            jmeter_plan: jmeter_plan,
            public_ip_address: "23.45.67.8#{index}",
            private_ip_address: "10.0.10.1#{index}",
            active: false
          )
        end
      end

      browser = Rack::Test::Session.new(Sinatra::Application)
      browser.get("/projects/#{project.id}/load_agents")
      expect(browser.last_response).to be_ok
      agents = JSON.parse(browser.last_response.body)
      expect(agents.size).to be == 4
    end
  end
end
