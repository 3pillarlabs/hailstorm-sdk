require 'spec_helper'
require 'hailstorm/initializer'
require 'ostruct'

describe Hailstorm::Initializer do

  context '.create_project!' do
    it 'should create the Hailstorm application project structure' do
      root_path = Dir.mktmpdir
      app_name = 'spec'
      gems = [
        OpenStruct.new(name: 'hailstorm', path: '/path/to/hailstorm-gem'),
        OpenStruct.new(name: 'hailstorm-cli', path: '/path/to/hailstorm-cli'),
      ]
      Hailstorm::Initializer.create_project!(root_path, app_name, true, gems)

      expect(File.directory?(File.join(root_path, app_name, Hailstorm.db_dir))).to be true
      expect(File.directory?(File.join(root_path, app_name, Hailstorm.app_dir))).to be true
      expect(File.directory?(File.join(root_path, app_name, Hailstorm.log_dir))).to be true
      expect(File.directory?(File.join(root_path, app_name, Hailstorm.tmp_dir))).to be true
      expect(File.directory?(File.join(root_path, app_name, Hailstorm.reports_dir))).to be true
      expect(File.directory?(File.join(root_path, app_name, Hailstorm.config_dir))).to be true
      expect(File.directory?(File.join(root_path, app_name, Hailstorm.vendor_dir))).to be true
      expect(File.directory?(File.join(root_path, app_name, Hailstorm.script_dir))).to be true


      expect(File.exist?(File.join(root_path, app_name, 'Gemfile'))).to be true
      expect(File.exist?(File.join(root_path, app_name, Hailstorm.script_dir, 'hailstorm'))).to be true
      expect(File.exist?(File.join(root_path, app_name, Hailstorm.config_dir, 'environment.rb'))).to be true
      expect(File.exist?(File.join(root_path, app_name, Hailstorm.config_dir, 'database.properties'))).to be true
      expect(File.exist?(File.join(root_path, app_name, Hailstorm.config_dir, 'boot.rb'))).to be true

      FileUtils.rm_rf(root_path)
    end
  end
end
