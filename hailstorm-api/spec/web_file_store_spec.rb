require 'spec_helper'
require 'tmpdir'
require 'web_file_store'
require 'hailstorm/support/configuration'

describe WebFileStore do
  context '#fetch_file' do
    it 'should fetch an existing file' do
      mock_response = mock(Net::HTTPSuccess)
      mock_response.stub!(:is_a?).and_return(true)
      mock_response.stub!(:body).and_return('<xml></xml>')
      Net::HTTP.stub!(:get_response).and_return(mock_response)
      Dir.mktmpdir do |tmp_path|
        wfs = WebFileStore.new
        args = {file_id: '123', file_name: 'a.xml', to_path: tmp_path}
        local_path = wfs.fetch_file(args)
        expect(local_path).to eq("#{tmp_path}/#{args[:file_name]}")
        expect(File.read(local_path)).to eq(mock_response.body)
      end
    end

    it 'should raise error if file not found' do
      mock_response = mock(Net::HTTPNotFound)
      mock_response.stub!(:is_a?).and_return(false)
      Net::HTTP.stub!(:get_response).and_return(mock_response)
      wfs = WebFileStore.new
      Dir.mktmpdir do |tmp_path|
        expect { wfs.fetch_file({file_id: '123', file_name: 'a.xml', to_path: tmp_path}) }.to raise_error(Net::HTTPError)
      end
    end
  end

  context '#fetch_jmeter_plans' do
    it 'should fetch list of all plans' do
      project = Hailstorm::Model::Project.create!(project_code: 'web_file_store')
      hailstorm_config = Hailstorm::Support::Configuration.new
      hailstorm_config.jmeter.add_test_plan('123/a.jmx')
      ProjectConfiguration.create!(project_id: project.id, stringified_config: deep_encode(hailstorm_config))

      wfs = WebFileStore.new
      expect(wfs.fetch_jmeter_plans(project.project_code)).to eq(['123/a'])
    end
  end

  context '#app_dir_tree' do
    it 'should fetch a hierarchy of plans' do
      project = Hailstorm::Model::Project.create!(project_code: 'web_file_store')
      hailstorm_config = Hailstorm::Support::Configuration.new
      hailstorm_config.jmeter.add_test_plan('123/a.jmx')
      hailstorm_config.jmeter.add_test_plan('234/b.jmx')
      ProjectConfiguration.create!(project_id: project.id, stringified_config: deep_encode(hailstorm_config))

      wfs = WebFileStore.new
      parent_node = wfs.app_dir_tree(project.project_code)
      expect(parent_node.keys.size).to be == 1
      expect(parent_node.keys.first).to eq(Hailstorm.app_dir)
      expect(parent_node[Hailstorm.app_dir]).to be_nil
    end
  end

  context '#transfer_jmeter_artifacts' do
    it 'should copy all files to provided path' do
      mock_response = mock(Net::HTTPSuccess)
      mock_response.stub!(:is_a?).and_return(true)
      mock_response.stub!(:body).and_return('<xml></xml>')
      Net::HTTP.stub!(:get_response).and_return(mock_response)

      project = Hailstorm::Model::Project.create!(project_code: 'web_file_store')
      hailstorm_config = Hailstorm::Support::Configuration.new
      hailstorm_config.jmeter.add_test_plan('123/a.jmx')
      hailstorm_config.jmeter.add_test_plan('234/b.jmx')
      hailstorm_config.jmeter.data_files = ['456/data.csv']
      ProjectConfiguration.create!(project_id: project.id, stringified_config: deep_encode(hailstorm_config))

      Dir.mktmpdir do |tmp_path|
        wfs = WebFileStore.new
        wfs.transfer_jmeter_artifacts(project.project_code, tmp_path)
        expect(File.exist?(File.join(tmp_path, 'a.jmx'))).to be_true
        expect(File.exist?(File.join(tmp_path, 'b.jmx'))).to be_true
        expect(File.exist?(File.join(tmp_path, 'data.csv'))).to be_true
      end
    end
  end
end
