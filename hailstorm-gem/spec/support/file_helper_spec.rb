require 'spec_helper'
require 'rspec'
require 'tmpdir'
require 'hailstorm/support/file_helper'

describe Hailstorm::Support::FileHelper do
  file_helper = Hailstorm::Support::FileHelper.new

  context '#gunzip_file' do
    it 'should gunzip and optional delete the gzip file' do
      can = "Hello World\n"
      temp_path = Dir.mktmpdir
      gzip_file_path = File.join(temp_path, 'spec.txt.gzip')
      Zlib::GzipWriter.open(gzip_file_path) { |gz| gz.write(can) }
      file_path = File.join(temp_path, 'spec.txt')
      file_helper.gunzip_file(gzip_file_path, file_path, true)
      expect(File.exist?(gzip_file_path)).to be_false
      expect(File.read(file_path)).to be == can
      FileUtils.rmtree(temp_path)
    end
  end
end
