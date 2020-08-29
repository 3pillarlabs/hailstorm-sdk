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
  end
end
