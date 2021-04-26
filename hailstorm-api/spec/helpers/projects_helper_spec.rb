# frozen_string_literal: true

require 'spec_helper'
require 'helpers/projects_helper'
require 'hailstorm/model/cluster'
require 'hailstorm/model/jmeter_plan'
require 'hailstorm/model/master_agent'
require 'hailstorm/model/data_center'

describe ProjectsHelper do
  before(:each) do
    @api_instance = Object.new
    @api_instance.extend(ProjectsHelper)
  end

  context '#project_attributes' do
    before(:each) do
      @project = Hailstorm::Model::Project.create!(project_code: 'projects_helper')
      @jmeter_plan = Hailstorm::Model::JmeterPlan.create!(project: @project,
                                                          test_plan_name: 'a',
                                                          content_hash: 'A',
                                                          active: false)

      @jmeter_plan.update_column(:active, true)
    end

    context 'when project has running instances in AWS cluster' do
      it 'should add live attribute' do
        cluster_instance = Hailstorm::Model::AmazonCloud.create!(project: @project,
                                                                 access_key: 'a',
                                                                 secret_key: 's',
                                                                 active: false)

        cluster_instance.update_column(:active, true)
        cluster = Hailstorm::Model::Cluster.create!(project: @project,
                                                    cluster_type: cluster_instance.class.name,
                                                    clusterable_id: cluster_instance.id)

        Hailstorm::Model::MasterAgent.create!(clusterable_id: cluster.clusterable_id,
                                              clusterable_type: cluster.cluster_type,
                                              jmeter_plan: @jmeter_plan,
                                              public_ip_address: '2.3.4.5',
                                              private_ip_address: '10.0.23.34',
                                              active: false,
                                              identifier: 'i-1234567890')

        attrs = @api_instance.project_attributes(@project)
        expect(attrs[:live]).to be true
      end
    end

    context 'when project has no running instances in AWS cluster' do
      it 'should set live attribute to false' do
        cluster_instance = Hailstorm::Model::AmazonCloud.create!(project: @project,
                                                                 access_key: 'a',
                                                                 secret_key: 's',
                                                                 active: false)

        cluster_instance.update_column(:active, true)
        Hailstorm::Model::Cluster.create!(project: @project,
                                          cluster_type: cluster_instance.class.name,
                                          clusterable_id: cluster_instance.id)

        attrs = @api_instance.project_attributes(@project)
        expect(attrs[:live]).to eq(false)
      end
    end

    context 'when project is configured with a data center cluster' do
      it 'should not add live attribute' do
        cluster_instance = Hailstorm::Model::DataCenter.create!(project: @project,
                                                                user_name: 'root',
                                                                ssh_identity: 'insecure',
                                                                machines: ['172.16.8.10'],
                                                                title: 'Local Test',
                                                                active: false)
        cluster_instance.update_column(:active, true)
        cluster = Hailstorm::Model::Cluster.create!(project: @project,
                                                    cluster_type: cluster_instance.class.name,
                                                    clusterable_id: cluster_instance.id)

        master_agent = Hailstorm::Model::MasterAgent.create!(clusterable_id: cluster.clusterable_id,
                                                             clusterable_type: cluster.cluster_type,
                                                             jmeter_plan: @jmeter_plan,
                                                             private_ip_address: '172.16.8.134',
                                                             active: false)

        master_agent.update_column(:active, true)
        attrs = @api_instance.project_attributes(@project)
        expect(attrs).to_not include(:live)
      end
    end

    context 'when all JMeter test plans are disabled' do
      it 'should add incomplete attribute' do
        config = Hailstorm::Support::Configuration.new
        config.jmeter.add_test_plan('123/a.jmx')
        config.jmeter.disabled_test_plans.push('123/a')
        config.jmeter.data_files.push('135/b.csv')
        config.clusters(:amazon_cloud) do |amz|
          amz.access_key = 'a'
          amz.secret_key = 'x'
          amz.region = 'us-east-1'
        end

        ProjectConfiguration.create!(project: @project, stringified_config: deep_encode(config))
        attrs = @api_instance.project_attributes(@project)
        expect(attrs).to include(:incomplete)
        expect(attrs[:incomplete]).to be == true
      end
    end
  end
end
