require 'spec_helper'
require 'tempfile'
require 'hailstorm/model/project'
require 'hailstorm/model/amazon_cloud'
require 'hailstorm/model/data_center'
require 'hailstorm/model/master_agent'
require 'hailstorm/support/configuration'

describe Hailstorm::Model::Project do
  context '.create' do
    context 'with defaults' do
      it 'should have JMeter version as 3.2' do
        project = Hailstorm::Model::Project.new(project_code: 'project_spec')
        project.save!
        expect(project.jmeter_version).to eq '5.2.1'
      end
    end

    context 'with :project_code' do
      it 'should replace non-alphanumeric characters with underscore' do
        project = Hailstorm::Model::Project.create!(project_code: 'z/x/a  0b-c.txt')
        expect(project.project_code).to be == 'z_x_a_0b_c_txt'
      end
    end

    context 'with :custom_jmeter_installer_url' do
      it 'should extract the JMeter version' do
        project = Hailstorm::Model::Project.new(project_code: 'project_spec',
                                                custom_jmeter_installer_url: 'http://whodunit.org/my-jmeter-3.2_rhode.tgz')
        project.save!
        expect(project.jmeter_version).to eq '3.2_rhode'
      end
    end
  end

  context '#setup' do
    before(:each) do
      @project = Hailstorm::Model::Project.new(project_code: 'project_spec')
      @mock_config = Hailstorm::Support::Configuration.new
    end

    context 'success paths' do
      it 'should reload its state after setup' do
        @project.save!
        allow(@project).to receive(:settings_modified?).and_return(true)
        Hailstorm.fs = instance_double(Hailstorm::Behavior::FileStore)
        allow(Hailstorm.fs).to receive(:fetch_jmeter_plans).and_return(%w[a])
        allow(Hailstorm.fs).to receive(:app_dir_tree).and_return({app: nil}.stringify_keys)
        allow(Hailstorm.fs).to receive(:transfer_jmeter_artifacts)

        jmeter_plan = Hailstorm::Model::JmeterPlan.new(project: @project,
                                                       test_plan_name: 'A',
                                                       content_hash: 'B',
                                                       properties: { NumUsers: 200 }.to_json)

        allow(Hailstorm::Model::JmeterPlan).to receive(:to_jmeter_plans) do
          jmeter_plan.save!
          jmeter_plan.update_column(:active, true)
        end

        @project.setup(config: Hailstorm::Support::Configuration.new)

        expect(@project.jmeter_plans.active.first).to eql(jmeter_plan)
        expect(@project.jmeter_plans.first).to eql(jmeter_plan)
      end

      context 'properties' do
        before(:each) do
          @project.serial_version = 'B'
          @project.settings_modified = true
          allow(Hailstorm::Model::JmeterPlan).to receive(:setup)
          allow(Hailstorm::Model::Cluster).to receive(:configure_all)
          allow(Hailstorm::Model::TargetHost).to receive(:configure_all)
        end

        context 'with custom JMeter URL' do
          it 'should be invalid if ends with something other than .tgz or .tar.gz' do
            @mock_config.jmeter.custom_installer_url = 'http://whodunit.org/my-jmeter-3.2_rhode.tar'
            expect { @project.setup(config: @mock_config) }.to raise_exception
            expect(@project.errors).to have_key(:custom_jmeter_installer_url)
          end
          it 'should have custom JMeter version' do
            @mock_config.jmeter.version = '2.6'
            @mock_config.jmeter.custom_installer_url = 'http://whodunit.org/my-jmeter-3.2_rhode.tgz'
            @project.setup(config: @mock_config)
            expect(@project.jmeter_version).to eq('3.2_rhode')
          end
          it 'should have file name without extension as version as a fallback' do
            @mock_config.jmeter.custom_installer_url = 'http://whodunit.org/rhode.tgz'
            @project.setup(config: @mock_config)
            expect(@project.jmeter_version).to eq('rhode')
          end
        end

        context 'with specified jmeter_version' do
          context '< 2.6' do
            it 'should raise error' do
              @mock_config.jmeter.version = '2.5.1'
              expect { @project.setup(config: @mock_config) }.to raise_exception
              expect(@project.errors).to have_key(:jmeter_version)
            end
          end

          context 'not matching x.y.z format' do
            it 'should raise error' do
              @mock_config.jmeter.version = '-1'
              expect { @project.setup(config: @mock_config) }.to raise_exception
              expect(@project.errors).to have_key(:jmeter_version)
            end
          end
        end
      end
    end

    context 'settings_modified? == false' do
      it 'should raise error' do
        allow(@project).to receive(:settings_modified?).and_return(false)
        expect { @project.setup(config: @mock_config) }.to raise_error(Hailstorm::Exception)
      end
    end

    context 'setup/configuration error' do
      it 'should set serial_version to nil and raise error' do
        allow(@project).to receive(:settings_modified?).and_return(true)
        allow(@project).to receive(:setup_jmeter_plans).and_raise(Hailstorm::Exception, 'mock error')
        allow(@project).to receive(:configure_clusters).and_raise(Hailstorm::Exception, 'mock error')
        allow(@project).to receive(:configure_target_hosts).and_raise(Hailstorm::Exception, 'mock error')
        expect(@project).to receive(:update_column).with(:serial_version, nil)
        expect { @project.setup(config: @mock_config) }.to raise_error(Hailstorm::Exception)
      end
    end
  end

  context '#start' do
    before(:each) do
      @mock_config = Hailstorm::Support::Configuration.new
    end

    context 'current_execution_cycle exists' do
      it 'should raise error' do
        project = Hailstorm::Model::Project.new(project_code: 'project_spec')
        allow(project).to receive(:current_execution_cycle).and_return(Hailstorm::Model::ExecutionCycle.new)
        expect { project.start(config: @mock_config) }
          .to(
            raise_error(Hailstorm::ExecutionCycleExistsException) { |error| expect(error.diagnostics).to_not be_blank }
          )
      end
    end

    context 'current_execution_cycle does not exist' do
      it 'should create a new execution_cycle' do
        project = Hailstorm::Model::Project.create!(project_code: 'project_spec')
        allow(project).to receive(:settings_modified?).and_return(true)
        expect(project).to receive(:setup)
        expect(Hailstorm::Model::TargetHost).to receive(:monitor_all)
        expect(Hailstorm::Model::Cluster).to receive(:generate_all_load)
        project.start(config: @mock_config)
        expect(project.current_execution_cycle.status.to_sym).to be == :started
      end

      it 'should raise error if setup fails' do
        project = Hailstorm::Model::Project.create!(project_code: 'project_spec')
        allow(project).to receive(:settings_modified?).and_return(true)
        allow(project).to receive(:setup).and_raise(Hailstorm::Exception)
        expect { project.start(config: @mock_config) }.to raise_error(Hailstorm::Exception)
        expect(project.execution_cycles.order(started_at: :desc).first.status.to_sym).to be == :aborted
      end

      it 'should raise error if target monitoring or load generation fails' do
        project = Hailstorm::Model::Project.create!(project_code: 'project_spec')
        allow(project).to receive(:settings_modified?).and_return(false)
        allow(Hailstorm::Model::TargetHost).to receive(:monitor_all).and_raise(Hailstorm::Exception)
        allow(Hailstorm::Model::Cluster).to receive(:generate_all_load).and_raise(Hailstorm::Exception)
        expect { project.start(config: @mock_config) }.to raise_error(Hailstorm::Exception)
        expect(project.execution_cycles.order(started_at: :desc).first.status.to_sym).to be == :aborted
      end
    end
  end

  context '#stop' do
    context 'current_execution_cycle does not exist' do
      it 'should raise error' do
        project = Hailstorm::Model::Project.new(project_code: 'project_spec')
        expect { project.stop }
          .to(
            raise_error(Hailstorm::ExecutionCycleNotExistsException) do |error|
              expect(error.diagnostics).to_not be_blank
              expect(error.message).to_not be_blank
            end
          )
      end
    end

    context 'current_execution_cycle exists' do
      it 'should stop load generation and target monitoring' do
        project = Hailstorm::Model::Project.new(project_code: 'project_spec')
        execution_cycle = Hailstorm::Model::ExecutionCycle.create!(project: project,
                                                                   status: :started,
                                                                   started_at: Time.now - 30.minutes)
        expect(Hailstorm::Model::Cluster).to receive(:stop_load_generation)
        expect(Hailstorm::Model::TargetHost).to receive(:stop_all_monitoring)
        project.stop
        execution_cycle.reload
        expect(execution_cycle.status.to_sym).to be == :stopped
      end

      it 'should ensure to stop target monitoring if stopping load generation failed' do
        project = Hailstorm::Model::Project.new(project_code: 'project_spec')
        execution_cycle = Hailstorm::Model::ExecutionCycle.create!(project: project,
                                                                   status: :started,
                                                                   started_at: Time.now - 30.minutes)
        allow(Hailstorm::Model::Cluster).to receive(:stop_load_generation).and_raise(Hailstorm::Exception)
        expect(Hailstorm::Model::TargetHost).to receive(:stop_all_monitoring).with(project,
                                                                                   project.current_execution_cycle,
                                                                                   create_target_stat: false)
        expect { project.stop }.to raise_error(Hailstorm::Exception)
        execution_cycle.reload
        expect(execution_cycle.status.to_sym).to be == :aborted
      end

      context 'asked to stop before script with fixed duration stops running' do
        it 'should not stop target monitoring' do
          project = Hailstorm::Model::Project.new(project_code: 'project_spec')
          Hailstorm::Model::ExecutionCycle.create!(project: project,
                                                   status: :started,
                                                   started_at: Time.now - 30.minutes)
          exception = Hailstorm::ThreadJoinException.new(Hailstorm::JMeterRunningException.new)
          expect(Hailstorm::Model::Cluster).to receive(:stop_load_generation).and_raise(exception)
          expect(Hailstorm::Model::TargetHost).to_not receive(:stop_all_monitoring)
          expect { project.stop }.to raise_error(Hailstorm::ThreadJoinException)
          expect(project.current_execution_cycle.status.to_sym).to be == :started
        end
      end
    end
  end

  context '#abort' do
    it 'should abort load generation and target monitoring' do
      project = Hailstorm::Model::Project.new(project_code: 'project_spec')
      execution_cycle = Hailstorm::Model::ExecutionCycle.create!(project: project,
                                                                 status: :started,
                                                                 started_at: Time.now - 30.minutes)

      expect(Hailstorm::Model::Cluster).to receive(:stop_load_generation).with(project, false, nil, true)
      expect(Hailstorm::Model::TargetHost).to receive(:stop_all_monitoring).with(project,
                                                                                 project.current_execution_cycle,
                                                                                 create_target_stat: false)
      project.abort
      execution_cycle.reload
      expect(execution_cycle.status.to_sym).to be == :aborted
    end
  end

  context '#terminate' do
    it 'should terminate the setup' do
      project = Hailstorm::Model::Project.create!(project_code: 'project_spec')
      project.update_column(:serial_version, 'some value')
      execution_cycle = Hailstorm::Model::ExecutionCycle.create!(project: project,
                                                                 status: :started,
                                                                 started_at: Time.now - 30.minutes)
      expect(Hailstorm::Model::Cluster).to receive(:terminate)
      expect(Hailstorm::Model::TargetHost).to receive(:terminate)
      project.terminate
      expect(project.current_execution_cycle).to be_nil
      expect(execution_cycle.reload.status.to_sym).to be == :terminated
      expect(project.serial_version).to be_nil
    end
  end

  context '#results' do
    before(:each) do
      @mock_config = Hailstorm::Support::Configuration.new
    end

    context 'show' do
      it 'should show selected execution cycles' do
        project = Hailstorm::Model::Project.new
        allow(Hailstorm::Model::ExecutionCycle).to receive(:execution_cycles_for_report).and_return([])
        expect(project.results(:show, cycle_ids: [1, 2, 3], config: @mock_config)).to be_empty
      end
    end

    context 'exclude' do
      it 'should exclude selected execution cycles' do
        project = Hailstorm::Model::Project.new
        selected_execution_cycle = Hailstorm::Model::ExecutionCycle.new
        expect(selected_execution_cycle).to receive(:excluded!)
        allow(Hailstorm::Model::ExecutionCycle).to receive(
                                                     :execution_cycles_for_report
                                                   ).and_return([selected_execution_cycle])
        project.results(:exclude, cycle_ids: [1], config: @mock_config)
      end
    end

    context 'include' do
      it 'should include selected execution cycles' do
        project = Hailstorm::Model::Project.new
        selected_execution_cycle = Hailstorm::Model::ExecutionCycle.new
        expect(selected_execution_cycle).to receive(:stopped!)
        allow(Hailstorm::Model::ExecutionCycle).to receive(
                                                     :execution_cycles_for_report
                                                   ).and_return([selected_execution_cycle])
        project.results(:include, cycle_ids: [1], config: @mock_config)
      end
    end

    context 'export' do
      context 'zip format' do
        it 'should create zip file' do
          project = Hailstorm::Model::Project.new(project_code: 'spec')

          selected = Hailstorm::Model::ExecutionCycle.new
          selected.id = 1
          expect(selected).to receive(:export_results) do
            seq_dir_path = File.join(Hailstorm.workspace(project.project_code).tmp_path, "SEQUENCE-#{selected.id}")
            FileUtils.mkdir_p(seq_dir_path)
            FileUtils.touch(File.join(seq_dir_path, 'a.jtl'))
          end

          zip_fs = double('fake_zip_file', mkdir: nil)
          expect(zip_fs).to receive(:add)
          allow(Zip::File).to receive(:open) do |_zip_file_path, _file_mode, &block|
            block.call(zip_fs)
          end

          Hailstorm.fs = instance_double(Hailstorm::Behavior::FileStore)
          allow(Hailstorm.fs).to receive(:export_jtl)
          allow(Hailstorm::Model::ExecutionCycle).to receive(:execution_cycles_for_report).and_return([selected])

          project.results(:export, cycle_ids: [selected.id], format: :zip, config: @mock_config)
        end
      end
    end

    context 'import' do
      before(:each) do
        Hailstorm.fs = instance_double(Hailstorm::Behavior::FileStore)
      end
      it 'should import with selected jmeter, cluster and execution cycle' do
        project = Hailstorm::Model::Project.create!(project_code: 'product_spec')
        allow(project).to receive(:setup)
        project.settings_modified = false
        exec_cycle = instance_double(Hailstorm::Model::ExecutionCycle)
        allow(project.execution_cycles).to receive(:where).and_return([exec_cycle])

        project.jmeter_plans.create!(test_plan_name: 'foo', content_hash: '63e456').update_column(:active, true)
        jmeter_plan = project.jmeter_plans.create(test_plan_name: 'bar', content_hash: '63e456')
        jmeter_plan.update_column(:active, true)

        project.clusters.create!(cluster_type: 'Hailstorm::Model::AmazonCloud')
        cluster = project.clusters.create!(cluster_type: 'Hailstorm::Model::DataCenter')
        allow_any_instance_of(Hailstorm::Model::DataCenter).to receive(:transfer_identity_file)
        data_center = cluster.cluster_klass.create!(user_name: 'zed',
                                                    ssh_identity: 'zed',
                                                    machines: ['172.16.80.25'],
                                                    title: '1d229',
                                                    project_id: project.id)
        data_center.update_column(:active, true)
        cluster.update_column(:clusterable_id, data_center.id)

        import_opts = { jmeter: jmeter_plan.test_plan_name, cluster: cluster.cluster_code, exec: '3' }
        expect(exec_cycle).to receive(:import_results).with(jmeter_plan, data_center, 'foo.jtl')
        allow(Hailstorm.fs).to receive(:copy_jtl).and_return('foo.jtl')
        project.results(:import, cycle_ids: [['foo.jtl'], import_opts.stringify_keys], config: @mock_config)
      end

      it 'should import from results_import_dir' do
        jtl_path = File.join(RSpec.configuration.build_path, 'a.jtl')
        FileUtils.touch(jtl_path)
        project = Hailstorm::Model::Project.new(project_code: 'project_spec')
        project.settings_modified = false
        expect(project).to respond_to(:jmeter_plans)
        allow(project).to receive_message_chain(:jmeter_plans, :all).and_return([Hailstorm::Model::JmeterPlan.new])
        cluster = Hailstorm::Model::Cluster.new
        allow(cluster).to receive(:cluster_instance).and_return(Hailstorm::Model::AmazonCloud.new)
        expect(project).to respond_to(:clusters)
        allow(project).to receive_message_chain(:clusters, :all).and_return([cluster])
        expect(project).to respond_to(:execution_cycles)
        execution_cycle = Hailstorm::Model::ExecutionCycle.new
        allow(project).to receive_message_chain(:execution_cycles, :create!).and_return(execution_cycle)
        expect(execution_cycle).to receive(:import_results)
        Hailstorm.fs = instance_double(Hailstorm::Behavior::FileStore)
        allow(Hailstorm.fs).to receive(:copy_jtl).and_return(jtl_path)
        project.results(:import, config: @mock_config, cycle_ids: [['a.jtl']])
      end
    end

    it 'should generate report by default' do
      expect(Hailstorm::Model::ExecutionCycle).to receive(:create_report).and_return('a.docx')
      Hailstorm.fs = instance_double(Hailstorm::Behavior::FileStore, export_report: nil)
      project = Hailstorm::Model::Project.new(project_code: 'some_code')
      project.results(:anything, cycle_ids: [1, 2], config: @mock_config)
    end
  end

  context '#check_status' do
    it 'should check cluster status' do
      expect(Hailstorm::Model::Cluster).to receive(:check_status)
      project = Hailstorm::Model::Project.new
      project.check_status
    end
  end

  context '#load_agents' do
    it 'should return list of all load_agents across clusters' do
      amz_cloud = Hailstorm::Model::AmazonCloud.new
      expect(amz_cloud).to respond_to(:load_agents)
      allow(amz_cloud).to receive(:load_agents).and_return(2.times.map { Hailstorm::Model::MasterAgent.new })
      cluster1 = Hailstorm::Model::Cluster.new
      expect(cluster1).to respond_to(:cluster_instance)
      allow(cluster1).to receive(:cluster_instance).and_return(amz_cloud)

      data_center = Hailstorm::Model::DataCenter.new
      expect(data_center).to respond_to(:load_agents)
      allow(data_center).to receive(:load_agents).and_return(3.times.map { Hailstorm::Model::MasterAgent.new })
      cluster2 = Hailstorm::Model::Cluster.new
      allow(cluster2).to receive(:cluster_instance).and_return(data_center)

      project = Hailstorm::Model::Project.new
      expect(project).to respond_to(:clusters)
      allow(project).to receive(:clusters).and_return([cluster1, cluster2])
      expect(project.load_agents.size).to be == 5
    end
  end

  context '#purge_clusters' do
    it 'should purge all clusters' do
      project = Hailstorm::Model::Project.new
      expect(project).to respond_to(:clusters)
      cluster = Hailstorm::Model::Cluster.new
      expect(cluster).to receive(:purge)
      allow(project).to receive(:clusters).and_return([cluster])
      project.purge_clusters
    end
  end

  context '#destroy' do
    it 'should remove the project workspace' do
      project = Hailstorm::Model::Project.create!(project_code: 'project_spec_remove_workspace')
      expect(project).to receive(:destroy_workspace)
      project.destroy!
    end
  end
end

