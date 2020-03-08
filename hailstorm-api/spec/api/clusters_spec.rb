require 'spec_helper'
require 'api/clusters'
require 'hailstorm/model/cluster'
require 'hailstorm/model/data_center'
require 'hailstorm/model/jmeter_plan'
require 'hailstorm/model/master_agent'
require 'hailstorm/model/execution_cycle'
require 'hailstorm/model/client_stat'

describe 'api/clusters' do
  before(:each) do
    @browser = Rack::Test::Session.new(Sinatra::Application)
  end

  context 'GET /projects/:project_id/clusters' do
    it 'should return empty list when there are no clusters' do
      project = Hailstorm::Model::Project.create!(project_code: File.strip_ext(File.basename(__FILE__)))
      ProjectConfiguration.create!(
        project_id: project.id,
        stringified_config: deep_encode(Hailstorm::Support::Configuration.new)
      )

      @browser.get("/projects/#{project.id}/clusters")
      expect(@browser.last_response).to be_ok
      res = JSON.parse(@browser.last_response.body)
      expect(res).to eq([])
    end

    it 'should return list of clusters' do
      hailstorm_config = Hailstorm::Support::Configuration.new
      hailstorm_config.clusters(:amazon_cloud) do |cluster|
        # @type [Hailstorm::Support::Configuration::AmazonCloud] cluster
        cluster.access_key = 'A'
        cluster.secret_key = 'a'
        cluster.region = 'us-east-1'
        cluster.instance_type = 'm5a.large'
        cluster.max_threads_per_agent = 50
      end

      hailstorm_config.clusters(:data_center) do |dc|
        # @type [Hailstorm::Support::Configuration::DataCenter] dc
        dc.title = 'Ice station Zebra'
        dc.user_name = 'ubuntu'
        dc.ssh_identity = '123/foo.pem'
        dc.machines = %W[172.16.0.10 172.16.0.20 172.16.0.30]
        dc.ssh_port = 8022
      end

      project = Hailstorm::Model::Project.create!(project_code: File.strip_ext(File.basename(__FILE__)))
      ProjectConfiguration.create!(
        project_id: project.id,
        stringified_config: deep_encode(hailstorm_config)
      )

      @browser.get("/projects/#{project.id}/clusters")
      expect(@browser.last_response).to be_ok
      res = JSON.parse(@browser.last_response.body)
      expect(res.size).to eq(2)
      expect(res[0].keys.sort).to eq(%W[id title type projectId accessKey secretKey instanceType maxThreadsByInstance region code].sort)
      expect(res[1].keys.sort).to eq(%W[id title type projectId userName sshIdentity machines port code].sort)
      expect(res[0]['type']).to eq('AWS')
      expect(res[1]['type']).to eq('DataCenter')
      expect(res[1]['sshIdentity']).to eq({name: 'foo.pem', path: '123'}.stringify_keys)
    end
  end

  context 'POST /projects/:project_id/clusters' do
    it 'should create an amazon cluster' do
      project = Hailstorm::Model::Project.create!(project_code: File.strip_ext(File.basename(__FILE__)))
      @browser.post("/projects/#{project.id}/clusters", JSON.dump({
        type: "AWS",
        accessKey: "A",
        secretKey: "s",
        instanceType: "t2.small",
        maxThreadsByInstance: 25,
        region: "us-east-1",
        title: ""
      }))

      expect(@browser.last_response).to be_ok
      res = JSON.parse(@browser.last_response.body).symbolize_keys
      expect(res).to include(:id)
      expect(res).to include(:code)
      expect(res).to include(:projectId)
      expect(res[:title]).to_not be_blank

      project_config = ProjectConfiguration.first
      expect(project_config).to_not be_nil
      hailstorm_config = deep_decode(project_config.stringified_config)
      expect(hailstorm_config.clusters.size).to be == 1
      expect(hailstorm_config.clusters[0].cluster_code).to eq(res[:code])
    end

    it 'should create an data-center cluster' do
      project = Hailstorm::Model::Project.create!(project_code: File.strip_ext(File.basename(__FILE__)))
      @browser.post("/projects/#{project.id}/clusters", JSON.dump({
        type: "DataCenter",
        title: "Bob's yard",
        userName: "ubuntu",
        sshIdentity: { name: 'a.pem', path: '123' },
        sshPort: 8022,
        machines: %W[172.16.0.10 172.16.0.20 172.16.0.30]
      }))

      expect(@browser.last_response).to be_ok
      res = JSON.parse(@browser.last_response.body).symbolize_keys
      expect(res).to include(:id)
      expect(res).to include(:code)
      expect(res).to include(:projectId)

      project_config = ProjectConfiguration.first
      expect(project_config).to_not be_nil
      hailstorm_config = deep_decode(project_config.stringified_config)
      expect(hailstorm_config.clusters.size).to be == 1
      expect(hailstorm_config.clusters[0].cluster_code).to eq(res[:code])
      expect(hailstorm_config.clusters[0].machines).to eq(res[:machines])
    end
  end

  context 'DELETE /projects/:project_id/clusters/:id' do
    before(:each) do
      @hailstorm_config = Hailstorm::Support::Configuration.new
      @hailstorm_config.clusters(:data_center) do |dc|
        # @type [Hailstorm::Support::Configuration::DataCenter] dc
        dc.title = 'Ice station Zebra'
        dc.user_name = 'ubuntu'
        dc.ssh_identity = '123/foo.pem'
        dc.machines = %W[172.16.0.10 172.16.0.20 172.16.0.30]
        dc.ssh_port = 8022
        dc.cluster_code = 'ice-station-zebra-119'
      end

      @project = Hailstorm::Model::Project.create!(project_code: File.strip_ext(File.basename(__FILE__)))
      ProjectConfiguration.create!(project: @project, stringified_config: deep_encode(@hailstorm_config))
      @cluster_id = @hailstorm_config.clusters.first.title.to_java_string.hash_code
    end

    context 'without existing tests' do
      it 'should remove the cluster from the configuration' do
        @browser.delete("/projects/#{@project.id}/clusters/#{@cluster_id}")
        expect(@browser.last_response.status).to be == 204

        updated_config = deep_decode(ProjectConfiguration.first.stringified_config)
        expect(updated_config.clusters).to be_blank
      end

      context 'with a persisted cluster' do
        before(:each) do
          dc_config = @hailstorm_config.clusters.first
          @data_center = Hailstorm::Model::DataCenter.create!(
            project: @project,
            user_name: dc_config.user_name,
            ssh_identity: dc_config.ssh_identity,
            machines: JSON.dump(dc_config.machines),
            title: dc_config.title,
            active: false,
            ssh_port: dc_config.ssh_port
          )

          @data_center.update_column(:active, true)

          Hailstorm::Model::Cluster.create!(
            project: @project,
            cluster_type: @data_center.class.name,
            clusterable_id: @data_center.id,
            cluster_code: dc_config.cluster_code
          )
        end

        it 'should destroy the cluster' do
          @browser.delete("/projects/#{@project.id}/clusters/#{@cluster_id}")
          expect(@browser.last_response.status).to be == 204

          expect(Hailstorm::Model::DataCenter.count).to be == 0
          expect(Hailstorm::Model::Cluster.count).to be == 0
        end

        context 'with load agents' do
          it 'should disable the cluster in the configuration' do
            jmeter_plan = Hailstorm::Model::JmeterPlan.create!(
              project: @project,
              test_plan_name: 'a',
              content_hash: 'A',
              active: false,
              properties: '{}'
            )

            jmeter_plan.update_column(:active, true)

            Hailstorm::Model::MasterAgent.create!(
              clusterable_id: @data_center.id,
              clusterable_type: @data_center.class.name,
              jmeter_plan: jmeter_plan,
              public_ip_address: '23.34.45.66',
              private_ip_address: '10.0.10.100',
              active: false,
              identifier: 'i-123456'
            ).update_column(:active, true)

            @browser.delete("/projects/#{@project.id}/clusters/#{@cluster_id}")
            expect(@browser.last_response.status).to be == 204

            expect(Hailstorm::Model::DataCenter.count).to be == 1
            expect(Hailstorm::Model::Cluster.count).to be == 1

            updated_config = deep_decode(ProjectConfiguration.first.stringified_config)
            expect(updated_config.clusters.first.active).to be == false
          end
        end
      end
    end

    context 'with existing tests' do
      it 'should disable the cluster in the configuration' do
        execution_cycle = Hailstorm::Model::ExecutionCycle.create!(
          project: @project,
          status: Hailstorm::Model::ExecutionCycle::States::STOPPED,
          started_at: Time.now.ago(30.minutes),
          stopped_at: Time.now,
          threads_count: 100
        )

        jmeter_plan = Hailstorm::Model::JmeterPlan.create!(
          project: @project,
          test_plan_name: 'a',
          content_hash: 'A',
          active: false,
          properties: '{}'
        )

        jmeter_plan.update_column(:active, true)

        dc_config = @hailstorm_config.clusters.first
        data_center = Hailstorm::Model::DataCenter.create!(
          project: @project,
          user_name: dc_config.user_name,
          ssh_identity: dc_config.ssh_identity,
          machines: JSON.dump(dc_config.machines),
          title: dc_config.title,
          active: false,
          ssh_port: dc_config.ssh_port
        )

        data_center.update_column(:active, true)

        Hailstorm::Model::Cluster.create!(
          project: @project,
          cluster_type: data_center.class.name,
          clusterable_id: data_center.id,
          cluster_code: dc_config.cluster_code
        )

        Hailstorm::Model::ClientStat.create!(
          execution_cycle: execution_cycle,
          jmeter_plan: jmeter_plan,
          clusterable_id: data_center.id,
          clusterable_type: data_center.class.name,
          threads_count: 100,
          aggregate_ninety_percentile: 123,
          aggregate_response_throughput: 89,
          last_sample_at: Time.now
        )

        @browser.delete("/projects/#{@project.id}/clusters/#{@cluster_id}")
        expect(@browser.last_response.status).to be == 204

        expect(Hailstorm::Model::DataCenter.count).to be == 1
        expect(Hailstorm::Model::Cluster.count).to be == 1

        updated_config = deep_decode(ProjectConfiguration.first.stringified_config)
        expect(updated_config.clusters.first.active).to be == false
      end
    end
  end

  context 'PATCH /projects/:project_id/clusters/:id' do
    it 'should update the cluster attributes in project configuration' do
      hailstorm_config = Hailstorm::Support::Configuration.new
      hailstorm_config.clusters(:data_center) do |dc|
        # @type [Hailstorm::Support::Configuration::DataCenter] dc
        dc.title = 'Ice station Zebra'
        dc.user_name = 'ubuntu'
        dc.ssh_identity = '123/foo.pem'
        dc.machines = %W[172.16.0.10 172.16.0.20 172.16.0.30]
        dc.ssh_port = 8022
        dc.cluster_code = 'ice-station-zebra-119'
        dc.active = false
      end

      project = Hailstorm::Model::Project.create!(project_code: File.strip_ext(File.basename(__FILE__)))
      ProjectConfiguration.create!(project: project, stringified_config: deep_encode(hailstorm_config))
      cluster_id = hailstorm_config.clusters.first.title.to_java_string.hash_code
      @browser.patch("/projects/#{project.id}/clusters/#{cluster_id}", JSON.dump({active: true}))
      expect(@browser.last_response.status).to be == 200
      project_config = ProjectConfiguration.first
      hailstorm_config = deep_decode(project_config.stringified_config)
      dc = hailstorm_config.clusters.first
      expect(dc.active).to be_true
    end
  end
end
