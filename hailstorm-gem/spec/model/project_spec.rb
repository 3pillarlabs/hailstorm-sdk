require 'spec_helper'
require 'hailstorm/model/project'

describe Hailstorm::Model::Project do

  context '.create' do
    context 'with defaults' do
      it 'should have JMeter version as 3.2' do
        project = Hailstorm::Model::Project.new(project_code: 'project_spec')
        project.save!
        expect(project.jmeter_version).to eq 3.2
      end
    end
  end

  context '#setup' do
    before(:each) do
      @project = Hailstorm::Model::Project.new(project_code: 'project_spec')
      @project.stub!(:setup_jmeter_plans)
      @project.stub!(:configure_clusters)
      @project.stub!(:configure_target_hosts)
      @project.stub!(settings_modified?: true)
      @mock_config = mock('config', serial_version: 'A', jmeter: OpenStruct.new,
                                    samples_breakup_interval: nil).as_null_object
      @project.stub!(:config).and_return(@mock_config)
    end

    context 'with custom JMeter URL' do
      it 'should be invalid if ends with something other than .tgz or .tar.gz' do
        @mock_config.jmeter.custom_installer_url = 'http://whodunit.org/my-jmeter-3.2_rhode.tar'
        expect { @project.setup }.to raise_exception
        expect(@project.errors).to have_key(:custom_jmeter_installer_url)
      end
      it 'should have custom JMeter version' do
        @mock_config.jmeter.custom_installer_url = 'http://whodunit.org/my-jmeter-3.2_rhode.tgz'
        @project.setup
        expect(@project.jmeter_version).to eq('3.2_rhode')
      end
      it 'should have file name without extension as version as a fallback' do
        @mock_config.jmeter.custom_installer_url = 'http://whodunit.org/rhode.tgz'
        @project.setup
        expect(@project.jmeter_version).to eq('rhode')
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
    end
  end

  context '#results' do
    context 'import' do
      it 'should import with selected jmeter, cluster and execution cycle' do
        project = Hailstorm::Model::Project.where(project_code: 'product_spec_results_import_selected_options').first_or_create!
        project.stub(:setup, nil)
        project.stub(:settings_modified?, false)
        Hailstorm::Model::ExecutionCycle.stub(:execution_cycles_for_report, [])
        exec_cycle = mock(Hailstorm::Model::ExecutionCycle)
        # exec_cycle.stub(:order, exec_cycle)
        project.execution_cycles.stub(:where).and_return([exec_cycle])
        project.jmeter_plans.where(test_plan_name: 'foo', content_hash: '63e456').first_or_create!(active: false)
                            .update_column(:active, true)
        jmeter_plan = project.jmeter_plans.where(test_plan_name: 'bar', content_hash: '63e456').first_or_create!(active: false)
        jmeter_plan.update_column(:active, true)
        project.clusters.all.each { |c| c.destroy! }
        project.clusters.create!(cluster_type: 'Hailstorm::Model::AmazonCloud')
        cluster = project.clusters
                         .create!(cluster_type: 'Hailstorm::Model::DataCenter')
        data_center = cluster.cluster_klass.where(user_name: 'zed', ssh_identity: 'zed', machines: '172.16.80.25',
                                                  title: '1d229', project_id: project.id)
                             .first_or_create!(active: false)
        data_center.update_column(:active, true)
        import_opts = {jmeter: jmeter_plan.test_plan_name, cluster: cluster.cluster_code, exec: '3'}
        exec_cycle.should_receive(:import_results).with(jmeter_plan, data_center, 'foo.jtl')
        project.results(:import, ['foo.jtl', import_opts.stringify_keys])
      end
    end
  end
end
