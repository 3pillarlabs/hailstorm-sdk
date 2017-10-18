require 'spec_helper'
require 'hailstorm/model/cluster'
require 'hailstorm/support/configuration'
require 'hailstorm/model/project'
require 'hailstorm/behavior/clusterable'
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
      unless ActiveRecord::Base.connection.table_exists?(:test_clusters)
        ActiveRecord::Migration.create_table(:test_clusters) do |t|
          t.references  :project, :null => false
          t.string      :name
          t.boolean     :active, :null => false, :default => false
          t.string      :user_name, :null => false
        end
      end
      @project = Hailstorm::Model::Project.where(project_code: 'cluster_spec').first_or_create!
      Hailstorm::Model::Cluster.where(project_id: @project.id).delete_all
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
end