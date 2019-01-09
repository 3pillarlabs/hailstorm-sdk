require 'spec_helper'
require 'rspec'
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
      require 'tmpdir'
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
end
