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
        expect(project.jmeter_version).to eq '3.2'
      end
    end
  end

  context '#setup' do
    before(:each) do
      @project = Hailstorm::Model::Project.new(project_code: 'project_spec')
    end

    context 'success paths' do
      before(:each) do
        Hailstorm.application.stub!(:load_config)
        @project.serial_version = 'B'
        Hailstorm::Model::JmeterPlan.stub!(:setup)
        Hailstorm::Model::Cluster.stub!(:configure_all)
        Hailstorm::Model::TargetHost.stub!(:configure_all)
        @mock_config = Hailstorm::Support::Configuration.new
        @mock_config.stub!(:serial_version).and_return('A')
        @project.stub!(:config).and_return(@mock_config)
      end

      context 'with custom JMeter URL' do
        it 'should be invalid if ends with something other than .tgz or .tar.gz' do
          @mock_config.jmeter.custom_installer_url = 'http://whodunit.org/my-jmeter-3.2_rhode.tar'
          expect { @project.setup }.to raise_exception
          expect(@project.errors).to have_key(:custom_jmeter_installer_url)
        end
        it 'should have custom JMeter version' do
          @mock_config.jmeter.version = '2.6'
          @mock_config.jmeter.custom_installer_url = 'http://whodunit.org/my-jmeter-3.2_rhode.tgz'
          @project.setup
          expect(@project.jmeter_version).to eq('3.2_rhode')
        end
        it 'should have file name without extension as version as a fallback' do
          @mock_config.jmeter.custom_installer_url = 'http://whodunit.org/rhode.tgz'
          @project.setup
          expect(@project.jmeter_version).to eq('rhode')
          expect(Hailstorm.application).to respond_to(:config)
        end
      end

      context 'with specified jmeter_version' do
        context '< 2.6' do
          it 'should raise error' do
            @mock_config.jmeter.version = '2.5.1'
            expect { @project.setup }.to raise_exception
            expect(@project.errors).to have_key(:jmeter_version)
          end
        end

        context 'not matching x.y.z format' do
          it 'should raise error' do
            @mock_config.jmeter.version = '-1'
            expect { @project.setup }.to raise_exception
            expect(@project.errors).to have_key(:jmeter_version)
          end
        end
      end
    end

    context 'settings_modified? == false' do
      it 'should raise error' do
        @project.stub!(:settings_modified?).and_return(false)
        expect { @project.setup }.to raise_error(Hailstorm::Exception)
      end
    end

    context 'setup/configuration error' do
      it 'should set serial_version to nil and raise error' do
        @project.stub!(:settings_modified?).and_return(true)
        @project.stub!(:setup_jmeter_plans).and_raise(Hailstorm::Exception, 'mock error')
        @project.stub!(:configure_clusters).and_raise(Hailstorm::Exception, 'mock error')
        @project.stub!(:configure_target_hosts).and_raise(Hailstorm::Exception, 'mock error')
        @project.stub!(:update_attributes!)
        @project.stub!(:config_attributes)
        @project.should_receive(:update_column).with(:serial_version, nil)
        expect { @project.setup }.to raise_error(Hailstorm::Exception)
      end
    end
  end

  context '#start' do
    context 'current_execution_cycle exists' do
      it 'should raise error' do
        project = Hailstorm::Model::Project.new(project_code: 'project_spec')
        project.stub!(:current_execution_cycle).and_return(Hailstorm::Model::ExecutionCycle.new)
        expect { project.start }
          .to(
            raise_error(Hailstorm::ExecutionCycleExistsException) { |error| expect(error.diagnostics).to_not be_blank }
          )
      end
    end

    context 'current_execution_cycle does not exist' do
      it 'should create a new execution_cycle' do
        project = Hailstorm::Model::Project.create!(project_code: 'project_spec')
        project.stub!(:settings_modified?).and_return(true)
        project.should_receive(:setup)
        Hailstorm::Model::TargetHost.should_receive(:monitor_all)
        Hailstorm::Model::Cluster.should_receive(:generate_all_load)
        project.start
        expect(project.current_execution_cycle.status.to_sym).to be == :started
      end

      it 'should raise error if setup fails' do
        project = Hailstorm::Model::Project.create!(project_code: 'project_spec')
        project.stub!(:settings_modified?).and_return(true)
        project.stub!(:setup).and_raise(Hailstorm::Exception)
        expect { project.start }.to raise_error(Hailstorm::Exception)
        expect(project.current_execution_cycle.status.to_sym).to be == :aborted
      end

      it 'should raise error if target monitoring or load generation fails' do
        project = Hailstorm::Model::Project.create!(project_code: 'project_spec')
        project.stub!(:settings_modified?).and_return(false)
        Hailstorm::Model::TargetHost.stub!(:monitor_all).and_raise(Hailstorm::Exception)
        Hailstorm::Model::Cluster.stub!(:generate_all_load).and_raise(Hailstorm::Exception)
        expect { project.start }.to raise_error(Hailstorm::Exception)
        expect(project.current_execution_cycle.status.to_sym).to be == :aborted
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
        Hailstorm::Model::ExecutionCycle.create!(project: project,
                                                 status: :started,
                                                 started_at: Time.now - 30.minutes)
        Hailstorm::Model::Cluster.should_receive(:stop_load_generation)
        Hailstorm::Model::TargetHost.should_receive(:stop_all_monitoring)
        project.stop
        expect(project.current_execution_cycle.status.to_sym).to be == :stopped
      end

      it 'should ensure to stop target monitoring if stopping load generation failed' do
        project = Hailstorm::Model::Project.new(project_code: 'project_spec')
        Hailstorm::Model::ExecutionCycle.create!(project: project,
                                                 status: :started,
                                                 started_at: Time.now - 30.minutes)
        Hailstorm::Model::Cluster.stub!(:stop_load_generation).and_raise(Hailstorm::Exception)
        Hailstorm::Model::TargetHost
            .should_receive(:stop_all_monitoring)
            .with(project, project.current_execution_cycle, create_target_stat: false)
        expect { project.stop }.to raise_error(Hailstorm::Exception)
        expect(project.current_execution_cycle.status.to_sym).to be == :aborted
      end
    end
  end

  context '#abort' do
    it 'should abort load generation and target monitoring' do
      project = Hailstorm::Model::Project.new(project_code: 'project_spec')
      Hailstorm::Model::ExecutionCycle.create!(project: project,
                                               status: :started,
                                               started_at: Time.now - 30.minutes)

      Hailstorm::Model::Cluster.should_receive(:stop_load_generation).with(project, false, nil, true)
      Hailstorm::Model::TargetHost
          .should_receive(:stop_all_monitoring)
          .with(project, project.current_execution_cycle, create_target_stat: false)
      project.abort
      expect(project.current_execution_cycle.status.to_sym).to be == :aborted
    end
  end

  context '#terminate' do
    it 'should terminate the setup' do
      project = Hailstorm::Model::Project.create!(project_code: 'project_spec')
      project.update_column(:serial_version, 'some value')
      Hailstorm::Model::ExecutionCycle.create!(project: project,
                                               status: :started,
                                               started_at: Time.now - 30.minutes)
      Hailstorm::Model::Cluster.should_receive(:terminate)
      Hailstorm::Model::TargetHost.should_receive(:terminate)
      project.terminate
      expect(project.current_execution_cycle.status.to_sym).to be == :terminated
      project.reload
      expect(project.serial_version).to be_nil
    end
  end

  context '#results' do

    context 'show' do
      it 'should show selected execution cycles' do
        project = Hailstorm::Model::Project.new
        Hailstorm::Model::ExecutionCycle.stub!(:execution_cycles_for_report).and_return([])
        expect(project.results(:show, [1, 2, 3])).to be_empty
      end
    end

    context 'exclude' do
      it 'should exclude selected execution cycles' do
        project = Hailstorm::Model::Project.new
        selected_execution_cycle = Hailstorm::Model::ExecutionCycle.new
        selected_execution_cycle.should_receive(:excluded!)
        Hailstorm::Model::ExecutionCycle
          .stub!(:execution_cycles_for_report)
          .and_return([selected_execution_cycle])
        project.results(:exclude, [1])
      end
    end

    context 'include' do
      it 'should include selected execution cycles' do
        project = Hailstorm::Model::Project.new
        selected_execution_cycle = Hailstorm::Model::ExecutionCycle.new
        selected_execution_cycle.should_receive(:stopped!)
        Hailstorm::Model::ExecutionCycle
            .stub!(:execution_cycles_for_report)
            .and_return([selected_execution_cycle])
        project.results(:include, [1])
      end
    end

    context 'export' do
      context 'zip format' do
        it 'should create zip file' do
          selected = Hailstorm::Model::ExecutionCycle.new
          selected.id = 1
          seq_path = File.join(Hailstorm.root, Hailstorm.reports_dir, "SEQUENCE-#{selected.id}")
          FileUtils.mkdir_p(seq_path)
          jtl_path = FileUtils.touch(File.join(seq_path, 'a.jtl'))
          selected.should_receive(:export_results).and_return(jtl_path)

          zip_fs = double('fake_zip_file', mkdir: nil)
          zip_fs.should_receive(:add)
          Zip::File.stub!(:open) do |_zip_file_path, _file_mode, &block|
            block.call(zip_fs)
          end

          Hailstorm::Model::ExecutionCycle.stub!(:execution_cycles_for_report).and_return([selected])
          project = Hailstorm::Model::Project.new
          project.results(:export, [1], :zip)
        end
      end
    end

    context 'import' do
      it 'should import with selected jmeter, cluster and execution cycle' do
        project = Hailstorm::Model::Project.create!(project_code: 'product_spec')
        project.stub!(:setup)
        project.stub!(:settings_modified?).and_return(false)
        Hailstorm::Model::ExecutionCycle.stub!(:execution_cycles_for_report).and_return([])
        exec_cycle = mock(Hailstorm::Model::ExecutionCycle)
        project.execution_cycles.stub(:where).and_return([exec_cycle])

        project.jmeter_plans.create!(test_plan_name: 'foo', content_hash: '63e456').update_column(:active, true)
        jmeter_plan = project.jmeter_plans.create(test_plan_name: 'bar', content_hash: '63e456')
        jmeter_plan.update_column(:active, true)

        project.clusters.create!(cluster_type: 'Hailstorm::Model::AmazonCloud')
        cluster = project.clusters.create!(cluster_type: 'Hailstorm::Model::DataCenter')
        data_center = cluster.cluster_klass.create!(user_name: 'zed',
                                                    ssh_identity: 'zed',
                                                    machines: ['172.16.80.25'],
                                                    title: '1d229',
                                                    project_id: project.id)
        data_center.update_column(:active, true)
        cluster.update_column(:clusterable_id, data_center.id)

        import_opts = { jmeter: jmeter_plan.test_plan_name, cluster: cluster.cluster_code, exec: '3' }
        exec_cycle.should_receive(:import_results).with(jmeter_plan, data_center, 'foo.jtl')
        project.results(:import, ['foo.jtl', import_opts.stringify_keys])
      end

      it 'should import from results_import_dir' do
        Hailstorm::Model::ExecutionCycle.stub!(:execution_cycles_for_report)
        FileUtils.mkdir_p(File.join(Hailstorm.root, Hailstorm.results_import_dir))
        FileUtils.touch(File.join(Hailstorm.root, Hailstorm.results_import_dir, 'a.jtl'))
        project = Hailstorm::Model::Project.new
        project.stub!(:settings_modified?).and_return(false)
        expect(project).to respond_to(:jmeter_plans)
        project.stub_chain(:jmeter_plans, :all).and_return([Hailstorm::Model::JmeterPlan.new])
        cluster = Hailstorm::Model::Cluster.new
        cluster.stub!(:cluster_instance).and_return(Hailstorm::Model::AmazonCloud.new)
        expect(project).to respond_to(:clusters)
        project.stub_chain(:clusters, :all).and_return([cluster])
        expect(project).to respond_to(:execution_cycles)
        execution_cycle = Hailstorm::Model::ExecutionCycle.new
        project.stub_chain(:execution_cycles, :create!).and_return(execution_cycle)
        execution_cycle.should_receive(:import_results)
        project.results(:import)
      end
    end

    it 'should generate report by default' do
      Hailstorm::Model::ExecutionCycle
        .should_receive(:create_report)
        .and_return(File.join(Hailstorm.root, Hailstorm.reports_dir, 'a.docx'))
      project = Hailstorm::Model::Project.new
      project.results(:anything, [1, 2])
    end
  end

  context '#check_status' do
    it 'should check cluster status' do
      Hailstorm::Model::Cluster.should_receive(:check_status)
      project = Hailstorm::Model::Project.new
      project.check_status
    end
  end

  context '#load_agents' do
    it 'should return list of all load_agents across clusters' do
      amz_cloud = Hailstorm::Model::AmazonCloud.new
      expect(amz_cloud).to respond_to(:load_agents)
      amz_cloud.stub!(:load_agents).and_return(2.times.map { Hailstorm::Model::MasterAgent.new })
      cluster1 = Hailstorm::Model::Cluster.new
      expect(cluster1).to respond_to(:cluster_instance)
      cluster1.stub!(:cluster_instance).and_return(amz_cloud)

      data_center = Hailstorm::Model::DataCenter.new
      expect(data_center).to respond_to(:load_agents)
      data_center.stub!(:load_agents).and_return(3.times.map { Hailstorm::Model::MasterAgent.new })
      cluster2 = Hailstorm::Model::Cluster.new
      cluster2.stub!(:cluster_instance).and_return(data_center)

      project = Hailstorm::Model::Project.new
      expect(project).to respond_to(:clusters)
      project.stub!(:clusters).and_return([cluster1, cluster2])
      expect(project.load_agents.size).to be == 5
    end
  end

  context '#purge_clusters' do
    it 'should purge all clusters' do
      project = Hailstorm::Model::Project.new
      expect(project).to respond_to(:clusters)
      cluster = Hailstorm::Model::Cluster.new
      cluster.should_receive(:purge)
      project.stub!(:clusters).and_return([cluster])
      project.purge_clusters
    end
  end
end

