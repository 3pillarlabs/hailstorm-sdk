require 'spec_helper'
require 'hailstorm/model/project'

describe Hailstorm::Model::Project do

  context '.create' do

    context 'with defaults' do
      it 'should have JMeter version as 3.2' do
        project = Hailstorm::Model::Project.new(project_code: 'project_spec_with_defaults')
        project.save!
        expect(project.jmeter_version).to eq 3.2
      end
    end
  end

  context '#setup' do

    context 'with custom JMeter URL' do
      before(:each) do
        @project = Hailstorm::Model::Project.new(project_code: 'product_spec_with_custom_jmeter_url')
      end
      it 'should be invalid if ends with something other than .tgz or .tar.gz' do
        @project.custom_jmeter_installer_url = 'http://whodunit.org/my-jmeter-3.2_rhode.tar'
        expect {
          @project.save!
        }.to raise_exception
        expect(@project.errors).to have_key(:custom_jmeter_installer_url)
      end
      it 'should have custom JMeter version' do
        @project.custom_jmeter_installer_url = 'http://whodunit.org/my-jmeter-3.2_rhode.tgz'
        expect(@project.send(:jmeter_version_from_installer_url)).to eq('3.2_rhode')
      end
      it 'should have file name without extension as version as a fallback' do
        @project.custom_jmeter_installer_url = 'http://whodunit.org/rhode.tgz'
        expect(@project.send(:jmeter_version_from_installer_url)).to eq('rhode')
      end
    end
  end

  context '#results' do

    context 'import' do

    end
  end
end
