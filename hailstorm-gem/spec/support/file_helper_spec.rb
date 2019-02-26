require 'spec_helper'
require 'rspec'
require 'tmpdir'
require 'hailstorm/support/file_helper'

describe Hailstorm::Support::FileHelper do
  file_helper = Hailstorm::Support::FileHelper.new

  context '#test_plans_enumerator' do
    it 'should return an enumerator' do
      expect(file_helper.dir_glob_enumerator(File.expand_path('../..', __FILE__))).to be_kind_of(Enumerator)
    end
  end

  context 'file?' do
    it 'should be true if path is a regular file' do
      expect(file_helper.file?(__FILE__)).to be_true
    end
    it 'should be false if path is not a regular file' do
      expect(file_helper.file?(File.expand_path('../..', __FILE__))).to be_false
    end
  end

  context '#local_app_directories' do
    it 'should return directory hierarchy' do
      temp_path = Dir.mktmpdir
      FileUtils.mkdir_p("#{temp_path}/a/b/d/e")
      FileUtils.mkdir_p("#{temp_path}/a/b/d/f")
      FileUtils.mkdir_p("#{temp_path}/a/c/g")
      key = File.basename(temp_path)
      structure = {
          key => {
              a: {
                  b: {
                      d: { e: nil, f: nil }
                  },
                  c: { g: nil }
              }
          }
      }.deep_stringify_keys
      expect(file_helper.local_app_directories(temp_path)).to eq(structure)
      expect(file_helper.local_app_directories("#{temp_path}/a")).to eq(structure[key])
      expect(file_helper.local_app_directories("#{temp_path}/a/b")).to eq({'b' => structure[key]['a']['b']})
      expect(file_helper.local_app_directories("#{temp_path}/a/b/d")).to eq(structure[key]['a']['b'])
      expect(file_helper.local_app_directories("#{temp_path}/a/b/d/e")).to eq({'e' => nil})
      expect(file_helper.local_app_directories("#{temp_path}/a/c")).to eq({'c' => structure[key]['a']['c']})
      FileUtils.rmtree(temp_path)
    end
  end

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
