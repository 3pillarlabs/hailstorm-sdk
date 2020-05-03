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
        @api_params[:machines] = %W[192.168.20.10 192.168.20.20]
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
end
