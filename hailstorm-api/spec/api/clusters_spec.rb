# frozen_string_literal: true

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
        dc.machines = %w[172.16.0.10 172.16.0.20 172.16.0.30]
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
      amz_keys = %w[
        id title type projectId accessKey secretKey instanceType maxThreadsByInstance region code vpcSubnetId baseAMI
      ]
      expect(res[0].keys.sort).to eq(amz_keys.sort)
      dc_keys = %w[id title type projectId userName sshIdentity machines port code]
      expect(res[1].keys.sort).to eq(dc_keys.sort)
      expect(res[0]['type']).to eq('AWS')
      expect(res[1]['type']).to eq('DataCenter')
      expect(res[1]['sshIdentity']).to eq({ name: 'foo.pem', path: '123' }.stringify_keys)
    end

    it 'should sort active clusters above disabled ones' do
      hailstorm_config = Hailstorm::Support::Configuration.new
      hailstorm_config.clusters(:amazon_cloud) do |cluster|
        # @type [Hailstorm::Support::Configuration::AmazonCloud] cluster
        cluster.access_key = 'A'
        cluster.secret_key = 'a'
        cluster.region = 'us-east-1'
        cluster.instance_type = 'm5a.large'
        cluster.max_threads_per_agent = 50
      end

      hailstorm_config.clusters(:amazon_cloud) do |cluster|
        # @type [Hailstorm::Support::Configuration::AmazonCloud] cluster
        cluster.access_key = 'A'
        cluster.secret_key = 'a'
        cluster.region = 'us-west-1'
        cluster.instance_type = 'm5a.large'
        cluster.max_threads_per_agent = 50
        cluster.active = false
      end

      hailstorm_config.clusters(:data_center) do |dc|
        # @type [Hailstorm::Support::Configuration::DataCenter] dc
        dc.title = 'Ice station Zebra'
        dc.user_name = 'ubuntu'
        dc.ssh_identity = '123/foo.pem'
        dc.machines = %w[172.16.0.10 172.16.0.20 172.16.0.30]
        dc.ssh_port = 8022
      end

      project = Hailstorm::Model::Project.create!(project_code: File.strip_ext(File.basename(__FILE__)))
      ProjectConfiguration.create!(
        project_id: project.id,
        stringified_config: deep_encode(hailstorm_config)
      )

      @browser.get("/projects/#{project.id}/clusters")
      puts @browser.last_response.body
      expect(@browser.last_response).to be_ok
      res = JSON.parse(@browser.last_response.body)
      expect(res[0]['disabled']).to be_nil
      expect(res[1]['disabled']).to be_nil
      expect(res[2]['disabled']).to be true
    end
  end

  context 'POST /projects/:project_id/clusters' do
    it 'should create an amazon cluster' do
      project = Hailstorm::Model::Project.create!(project_code: File.strip_ext(File.basename(__FILE__)))
      @browser.post("/projects/#{project.id}/clusters", JSON.dump({
                                                                    type: 'AWS',
                                                                    accessKey: 'A',
                                                                    secretKey: 's',
                                                                    instanceType: 't2.small',
                                                                    maxThreadsByInstance: 25,
                                                                    region: 'us-east-1',
                                                                    title: ''
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
                                                                    type: 'DataCenter',
                                                                    title: "Bob's yard",
                                                                    userName: 'ubuntu',
                                                                    sshIdentity: { name: 'a.pem', path: '123' },
                                                                    sshPort: 8022,
                                                                    machines: %w[172.16.0.10 172.16.0.20 172.16.0.30]
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

    context 'when Amazon cluster with unsupported region' do
      context 'when custom base_ami is not provided' do
        it 'should not persist configuration' do
          allow_any_instance_of(Hailstorm::Model::Helper::AwsRegionHelper).to receive(:region_base_ami_map)
            .and_return('us-east-1' => 'ami-123')
          project = Hailstorm::Model::Project.create!(project_code: File.strip_ext(File.basename(__FILE__)))
          params = {
            type: 'AWS',
            accessKey: 'A',
            secretKey: 's',
            instanceType: 't2.small',
            maxThreadsByInstance: 25,
            region: 'us-east-1000',
            title: ''
          }

          @browser.post("/projects/#{project.id}/clusters", JSON.dump(params))
          expect(@browser.last_response.status).to be == 422

          params.merge!(baseAMI: 'ami-123')
          @browser.post("/projects/#{project.id}/clusters", JSON.dump(params))
          expect(@browser.last_response).to be_ok
          project_config = ProjectConfiguration.first
          expect(project_config).to_not be_nil
          hailstorm_config = deep_decode(project_config.stringified_config)
          expect(hailstorm_config.clusters.size).to be == 1
          expect(hailstorm_config.clusters[0].base_ami).to eq(params[:baseAMI])
        end
      end
    end

    context 'when Amazon cluster in supported region' do
      it 'should not accept custom base_ami' do
        allow_any_instance_of(Hailstorm::Model::Helper::AwsRegionHelper).to receive(:region_base_ami_map)
          .and_return('us-east-1' => 'ami-123')
        project = Hailstorm::Model::Project.create!(project_code: File.strip_ext(File.basename(__FILE__)))
        @browser.post("/projects/#{project.id}/clusters", JSON.dump({
                                                                      type: 'AWS',
                                                                      accessKey: 'A',
                                                                      secretKey: 's',
                                                                      instanceType: 't2.small',
                                                                      maxThreadsByInstance: 25,
                                                                      region: 'us-east-1',
                                                                      title: '',
                                                                      baseAMI: 'ami-123'
                                                                    }))

        expect(@browser.last_response.status).to be == 422
      end
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
        dc.machines = %w[172.16.0.10 172.16.0.20 172.16.0.30]
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
    before(:each) do
      @project = Hailstorm::Model::Project.create!(project_code: File.strip_ext(File.basename(__FILE__)))
      @hailstorm_config = Hailstorm::Support::Configuration.new
    end

    context 'any kind of cluster' do
      before(:each) do
        @hailstorm_config.clusters(:data_center) do |dc|
          # @type [Hailstorm::Support::Configuration::DataCenter] dc
          dc.title = 'Ice station Zebra'
          dc.user_name = 'ubuntu'
          dc.ssh_identity = '123/foo.pem'
          dc.machines = %w[172.16.0.10 172.16.0.20 172.16.0.30]
          dc.ssh_port = 8022
          dc.cluster_code = 'ice-station-zebra-119'
          dc.active = false
        end

        ProjectConfiguration.create!(project: @project, stringified_config: deep_encode(@hailstorm_config))
        @cluster_id = @hailstorm_config.clusters.first.title.to_java_string.hash_code
      end

      it 'should be able to activate the cluster' do
        @browser.patch("/projects/#{@project.id}/clusters/#{@cluster_id}", JSON.dump({ active: true }))
        expect(@browser.last_response.status).to be == 200
        project_config = ProjectConfiguration.first
        hailstorm_config = deep_decode(project_config.stringified_config)
        dc = hailstorm_config.clusters.first
        expect(dc.active).to be true
      end

      it 'should be able to de-activate the cluster' do
        @hailstorm_config.clusters.first.active = true
        ProjectConfiguration.first.update_attributes!(stringified_config: deep_encode(@hailstorm_config))
        @browser.patch("/projects/#{@project.id}/clusters/#{@cluster_id}", JSON.dump({ active: false }))
        expect(@browser.last_response.status).to be == 200
        project_config = ProjectConfiguration.first
        hailstorm_config = deep_decode(project_config.stringified_config)
        dc = hailstorm_config.clusters.first
        expect(dc.active).to be false
      end

      context 'cluster is disabled' do
        it 'should not update any field other than active' do
          @browser.patch("/projects/#{@project.id}/clusters/#{@cluster_id}", JSON.dump({ user_name: 'root' }))
          expect(@browser.last_response.status).to be == 422
        end
      end

      it 'should not update cluster_code' do
        @browser.patch("/projects/#{@project.id}/clusters/#{@cluster_id}", JSON.dump({ code: 'bot-cluster-200' }))
        expect(@browser.last_response.status).to be == 422
        project_config = ProjectConfiguration.first
        hailstorm_config = deep_decode(project_config.stringified_config)
        # @type [Hailstorm::Support::Configuration::DataCenter] dc
        dc = hailstorm_config.clusters.first
        expect(dc.cluster_code).to be == 'ice-station-zebra-119' # unchanged in the update
      end

      context 'project is running tests' do
        it 'should not update any attribute' do
          Hailstorm::Model::ExecutionCycle.create!(
            project: @project,
            status: Hailstorm::Model::ExecutionCycle::States::STARTED,
            started_at: Time.now.ago(30.minutes),
            threads_count: 100
          )

          @browser.patch("/projects/#{@project.id}/clusters/#{@cluster_id}", JSON.dump({ active: true }))
          expect(@browser.last_response.status).to be == 422
          project_config = ProjectConfiguration.first
          hailstorm_config = deep_decode(project_config.stringified_config)
          # @type [Hailstorm::Support::Configuration::DataCenter] dc
          dc = hailstorm_config.clusters.first
          expect(dc.active).to be_blank
        end
      end
    end

    context 'when AWS cluster' do
      before(:each) do
        @cluster_id = 'AWS us-east-1'.to_java_string.hash_code
        @hailstorm_config.clusters(:amazon_cloud) do |amz|
          # @type [Hailstorm::Support::Configuration::AmazonCloud] amz
          amz.access_key = 'A'
          amz.secret_key = 's'
          amz.region = 'us-east-1'
          amz.active = true
        end

        ProjectConfiguration.create!(project: @project, stringified_config: deep_encode(@hailstorm_config))
      end

      it 'should not update region' do
        @browser.patch("/projects/#{@project.id}/clusters/#{@cluster_id}", JSON.dump({ region: 'us-west-1' }))
        expect(@browser.last_response.status).to be == 422
      end

      context 'for a supported region' do
        it 'should not update base AMI' do
          @browser.patch("/projects/#{@project.id}/clusters/#{@cluster_id}", JSON.dump({ base_ami: 'ami-123' }))
          expect(@browser.last_response.status).to be == 422
        end
      end

      context 'project is live on AWS cluster' do
        it 'should update only Max users per instance' do
          allow_any_instance_of(@project.class).to receive(:load_agents)
            .and_return([double(Hailstorm::Model::MasterAgent)])
          @browser.patch("/projects/#{@project.id}/clusters/#{@cluster_id}", JSON.dump({ access_key: 'B' }))
          expect(@browser.last_response.status).to be == 422

          @browser.patch("/projects/#{@project.id}/clusters/#{@cluster_id}",
                         JSON.dump({ max_threads_per_agent: 100 }))
          expect(@browser.last_response.status).to be == 200
        end
      end
    end

    context 'when DataCenter cluster' do
      before(:each) do
        @hailstorm_config.clusters(:data_center) do |dc|
          # @type [Hailstorm::Support::Configuration::DataCenter] dc
          dc.title = 'Bot cluster 2'
          dc.user_name = 'root'
          dc.ssh_identity = '123/foo.pem'
          dc.machines = %w[172.16.0.10 172.16.0.20]
          dc.ssh_port = 22
          dc.cluster_code = 'bot-cluster-2'
        end

        ProjectConfiguration.create!(project: @project, stringified_config: deep_encode(@hailstorm_config))
        @cluster_id = @hailstorm_config.clusters.first.title.to_java_string.hash_code
      end

      it 'should update all allowed attributes' do
        request_params = {
          title: 'Bot cluster 1',
          userName: 'ubuntu',
          sshIdentity: { name: 'secure.pem', path: '1234' },
          sshPort: 8022,
          machines: %w[172.16.0.10 172.16.0.20 172.16.0.30]
        }

        @browser.patch("/projects/#{@project.id}/clusters/#{@cluster_id}", JSON.dump(request_params))
        expect(@browser.last_response.status).to be == 200
        project_config = ProjectConfiguration.first
        hailstorm_config = deep_decode(project_config.stringified_config)
        # @type [Hailstorm::Support::Configuration::DataCenter] dc
        dc = hailstorm_config.clusters.first
        expect(dc.title).to be == request_params[:title]
        expect(dc.user_name).to be == request_params[:userName]
        expect(dc.ssh_identity).to be == "#{request_params[:sshIdentity][:path]}/#{request_params[:sshIdentity][:name]}"
        expect(dc.machines).to be == request_params[:machines]
        expect(dc.ssh_port).to be == request_params[:sshPort]
        expect(dc.cluster_code).to be == 'bot-cluster-2' # unchanged in the update
      end
    end
  end
end
