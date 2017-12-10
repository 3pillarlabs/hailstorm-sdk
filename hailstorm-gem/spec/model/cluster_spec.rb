require 'spec_helper'

require 'hailstorm/behavior/clusterable'
require 'hailstorm/model/cluster'
require 'hailstorm/model/project'
require 'hailstorm/model/amazon_cloud'
require 'hailstorm/support/configuration'

require 'active_record/base'

module Hailstorm
  module Model
    class TestCluster < ActiveRecord::Base
      include Hailstorm::Behavior::Clusterable
      def setup(*args)
        # noop
      end
    end
  end
end

class Hailstorm::Support::Configuration
  class TestCluster < Hailstorm::Support::Configuration::ClusterBase
    attr_accessor :name
  end
end

describe Hailstorm::Model::Cluster do
  context '.configure_all' do
    before(:each) do
      @project = Hailstorm::Model::Project.where(project_code: 'cluster_spec').first_or_create!
    end
    context '#active=true' do
      it 'should get persisted' do
        config = Hailstorm::Support::Configuration.new
        config.clusters(:test_cluster) do |cluster|
          cluster.user_name = 'jed'
          cluster.name = 'active_cluster'
        end
        Hailstorm::Model::Cluster.configure_all(@project, config)
        expect(Hailstorm::Model::Cluster.where(project_id: @project.id).count).to eql(1)
      end
    end
    context '#active=false' do
      it 'should get persisted' do
        config = Hailstorm::Support::Configuration.new
        config.clusters(:test_cluster) do |cluster|
          cluster.user_name = 'jed'
          cluster.name = 'inactive_cluster'
          cluster.active = false
        end
        Hailstorm::Model::Cluster.configure_all(@project, config)
        expect(Hailstorm::Model::Cluster.where(project_id: @project.id).count).to eql(1)
      end
    end
  end

  context '#configure' do
    context ':amazon_cloud' do
      it 'should persist all configuration options' do
        config = Hailstorm::Support::Configuration.new
        config.clusters(:amazon_cloud) do |aws|
          aws.access_key = 'blah'
          aws.secret_key = 'blahblah'
          aws.ssh_identity = 'insecure'
          aws.ssh_port = 8022
          aws.active = false
        end
        cluster = Hailstorm::Model::Cluster.new(cluster_type: Hailstorm::Model::AmazonCloud.to_s)
        cluster.project = Hailstorm::Model::Project.where(project_code: 'cluster_spec').first_or_create!
        cluster.save!
        cluster.configure(config.clusters.first)
        amz_cloud = Hailstorm::Model::AmazonCloud.where(project_id: cluster.project.id)
        expect(amz_cloud.first).to_not be_nil
        expect(amz_cloud.first.ssh_port).to eql(8022)
      end
    end
  end
end
