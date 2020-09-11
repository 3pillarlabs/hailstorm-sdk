# frozen_string_literal: true

require 'ostruct'
require 'spec_helper'
require 'helpers/clusters_helper'
require 'hailstorm/support/configuration'

describe ClustersHelper do
  before(:each) do
    @cluster_api_sim = Object.new
    @cluster_api_sim.extend(ClustersHelper)
  end

  context '#data_center_config' do
    before(:each) do
      @data_center = Hailstorm::Support::Configuration::DataCenter.new
      @api_params = {
        title: 'Cluster One',
        userName: 'root',
        sshIdentity: { path: '123', name: 'insecure.pem' }.stringify_keys,
        port: 22
      }
    end

    context 'params[:machines] is an array' do
      it 'should assign array of machines' do
        @api_params[:machines] = %w[192.168.20.10 192.168.20.20]
        @cluster_api_sim.data_center_config(@data_center, @api_params)
        expect(@data_center.machines).to be_a_kind_of(Array)
        expect(@data_center.machines).to eq(@api_params[:machines])
      end
    end

    context 'params[:machines] is a string' do
      it 'should assign array of machines' do
        @api_params[:machines] = '192.168.20.10'
        @cluster_api_sim.data_center_config(@data_center, @api_params)
        expect(@data_center.machines).to be_a_kind_of(Array)
        expect(@data_center.machines).to eq([@api_params[:machines]])
      end
    end
  end

  context '#to_cluster_attributes' do
    it 'should extract common attributes from a cluster' do
      cluster_cfg = OpenStruct.new({ cluster_type: 'any', cluster_code: 'cluster-1', active: true })
      cluster = Hailstorm::Model::Cluster.new
      allow(cluster).to receive_message_chain(:cluster_instance, :client_stats, :count).and_return(2)
      allow(cluster).to receive_message_chain(:cluster_instance, :load_agents, :count).and_return(3)
      allow(Hailstorm::Model::Cluster).to receive_message_chain(:where, :find_by_cluster_code).and_return(cluster)
      cluster_attrs = @cluster_api_sim.to_cluster_attributes(cluster_cfg, project: Hailstorm::Model::Project.new)
      expect(cluster_attrs.keys.sort).to eq(%w[code clientStatsCount loadAgentsCount].sort)
    end
  end

  context '#sort_clusters' do
    it 'should put all active clusters on top' do
      clusters = [
        { disabled: true },
        {},
        {},
        { disabled: true },
        {}
      ]

      sorted = clusters.map(&:stringify_keys).sort { |a, b| @cluster_api_sim.sort_clusters(a, b) }
      expect(sorted).to eq([{}, {}, {}, { disabled: true }.stringify_keys, { disabled: true }.stringify_keys])
    end
  end
end
