require 'spec_helper'
require 'api/clusters'

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
    it 'should disable the cluster in the configuration'
  end
end
