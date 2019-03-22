require 'spec_helper'
require 'hailstorm/model/target_host'
require 'hailstorm/model/target_stat'
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
  context '.host_definitions' do
    it 'should transform host configuration to an iterable' do
      config = Hailstorm::Support::Configuration.new
      config.monitors(:nmon) do |monitor|
        # default settings
        monitor.active            = true # if false, all hosts in this block will be ignored
        monitor.executable_path   = '/usr/bin/nmon'
        monitor.ssh_identity      = 'peen'
        monitor.user_name         = 'naani'
        monitor.sampling_interval = 5

        monitor.groups do |group|
          group.role = 'Web Server' # all web-servers go to this group
          group.hosts do |host|
            host.host_name = 'web01.example.com'
            host.executable_path = '/usr/local/bin/nmon' # overrides default setting for executable_path
            host.user_name = 'webmin' # overrides default setting for user_name
            host.sampling_interval = 10 # overrides default setting for sampling_interval
            host.active = false # disables target monitoring for this specific host
          end

          # add multiple hosts by separating them with a comma
          # the monitor settings apply to these hosts
          group.hosts('web02.example.com', 'web03.example.com')
        end
      end

      # set up multiple monitor blocks, everything would be aggregated.
      config.monitors(:nmon) do |monitor|
        monitor.executable_path   = '/usr/bin/nmon'
        monitor.ssh_identity      = 'papi'
        monitor.user_name         = 'elsa'
        monitor.sampling_interval = 5

        monitor.groups('Application Server') do |group|
          group.hosts('s01.hailstorm.com')
        end
      end

      host_defs = Hailstorm::Model::TargetHost.host_definitions(config.monitors)
      expect(host_defs.size).to be == 4
    end
  end
  
  context '.configure_all' do
    before(:each) do
      @project = Hailstorm::Model::Project.create!(project_code: 'target_host_spec')
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

      context 'previously persisted target_host' do
        it 'should be updated with new attributes' do
          Hailstorm::Model::TestMonitor.create!(host_name: 's01',
                                                role_name: 'server',
                                                sampling_interval: 5,
                                                project: @project)
          config = Hailstorm::Support::Configuration.new
          config.monitors(:test_monitor) do |monitor|
            monitor.sampling_interval = 10
            monitor.groups('Application Server') do |group|
              group.hosts('s01')
            end
          end
          Hailstorm::Model::TargetHost.configure_all(@project, config)
          expect(Hailstorm::Model::TargetHost.count).to eql(1)
          target_host = Hailstorm::Model::TargetHost.first
          expect(target_host).to be_active
          expect(target_host.sampling_interval).to be == 10
          expect(target_host.role_name).to be == 'Application Server'
        end
      end

      context '#setup failure' do
        it 'should set target host inactive and raise error' do
          Hailstorm::Model::TestMonitor
            .any_instance
            .stub(:setup)
            .and_raise(Hailstorm::Exception, 'mock exception')
          config = Hailstorm::Support::Configuration.new
          config.monitors(:test_monitor) do |monitor|
            monitor.sampling_interval = 10
            monitor.groups('Application Server') do |group|
              group.hosts('s01')
            end
          end
          expect { Hailstorm::Model::TargetHost.configure_all(@project, config) }
            .to raise_error(Hailstorm::Exception, 'mock exception')
          target_host = Hailstorm::Model::TargetHost.first
          expect(target_host).to_not be_active
        end
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

  context '.monitor_all' do
    it 'should start monitoring on all target hosts' do
      project = Hailstorm::Model::Project.create!(project_code: 'target_host_spec')
      Hailstorm::Model::TestMonitor.create!(host_name: 's01',
                                            role_name: 'server',
                                            sampling_interval: 5,
                                            active: true,
                                            project: project)
      Hailstorm::Model::TestMonitor.any_instance.should_receive(:start_monitoring)
      Hailstorm::Model::TargetHost.monitor_all(project)
    end
  end

  context '.stop_all_monitoring' do
    it 'should stop_monitoring on active target hosts' do
      project = Hailstorm::Model::Project.create!(project_code: 'target_host_spec')
      Hailstorm::Model::TestMonitor.create!(host_name: 's01',
                                            role_name: 'server',
                                            sampling_interval: 5,
                                            active: true,
                                            project: project)
      Hailstorm::Model::TestMonitor.any_instance.should_receive(:stop_monitoring)
      Hailstorm::Model::TargetStat.should_receive(:create_target_stat)
      Hailstorm::Model::TargetHost.stop_all_monitoring(project,
                                                       project.current_execution_cycle,
                                                       create_target_stat: true)
    end
  end

  context '.terminate' do
    it 'should cleanup on all target hosts' do
      project = Hailstorm::Model::Project.create!(project_code: 'target_host_spec')
      Hailstorm::Model::TestMonitor.create!(host_name: 's01',
                                            role_name: 'server',
                                            sampling_interval: 5,
                                            active: true,
                                            project: project)
      Hailstorm::Model::TestMonitor.any_instance.should_receive(:cleanup)
      Hailstorm::Model::TargetHost.terminate(project)
    end
  end
end
