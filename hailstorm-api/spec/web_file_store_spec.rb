require 'spec_helper'
require 'tmpdir'
require 'web_file_store'

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
end
