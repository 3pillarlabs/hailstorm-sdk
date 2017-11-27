require 'spec_helper'
require 'hailstorm/model/target_host'
require 'hailstorm/model/project'
require 'hailstorm/support/configuration'

module Hailstorm
  module Model
    class TestMonitor < TargetHost
      #
    end
  end
end

describe Hailstorm::Model::TargetHost do
  context '.configure_all' do
    before(:each) do
      @project = Hailstorm::Model::Project.where(project_code: 'target_host_spec').first_or_create!
    end
    context '#active=true' do
      it 'should be persisted' do
        config = Hailstorm::Support::Configuration.new
        config.monitors(:test_monitor) do |monitor|
          monitor.sampling_interval = 10
          monitor.groups('Application Server') do |group|
            group.hosts('s01.hailstorm.com')
          end
        end
        Hailstorm::Model::TargetHost.configure_all(@project, config)
        expect(Hailstorm::Model::TargetHost.count).to eql(1)
        expect(Hailstorm::Model::TargetHost.first).to be_active
      end
    end
    context '#active=false' do
      it 'should be persisted' do
        config = Hailstorm::Support::Configuration.new
        config.monitors(:test_monitor) do |monitor|
          monitor.sampling_interval = 10
          monitor.groups('Database Server') do |group|
            group.hosts do |host|
              host.host_name = 's02.hailstorm.com'
              host.active = false
            end
          end
        end
        Hailstorm::Model::TargetHost.configure_all(@project, config)
        expect(Hailstorm::Model::TargetHost.count).to eql(1)
        expect(Hailstorm::Model::TargetHost.first).to_not be_active
      end
    end
  end
end
