require 'spec_helper'
require 'hailstorm/support/configuration'

describe Hailstorm::Support::Configuration do

  def write_jtl(file_name)
    app_path = File.join(Hailstorm.root, Hailstorm.app_dir)
    FileUtils.mkdir_p(app_path)
    jmeter_plan_path = File.join(app_path, "#{file_name}.jmx")
    File.open(jmeter_plan_path, 'w') do |file|
      file.write('<xml></xml>')
    end
  end

  def write_configuration_file(num_lines: )
    FileUtils.mkdir_p(File.join(Hailstorm.root, Hailstorm.config_dir))
    File.open(Hailstorm.environment_file_path, 'w') do |file|
      num_lines.times do |index|
        file.puts("line #{index}")
      end
    end
  end

  context '#serial_version' do
    before(:all) do
      FileUtils.rm_rf(File.join(Hailstorm.root, Hailstorm.app_dir))
    end

    it 'should compute the digest of JMeter plans and configuration file' do
      %w[a b].each(&method(:write_jtl))
      write_configuration_file(num_lines: 2)

      configuration = Hailstorm::Support::Configuration.new
      expect(configuration.serial_version).to_not be_nil
    end

    it 'should change if a new JMeter plan is added' do
      %w[a b].each(&method(:write_jtl))
      write_configuration_file(num_lines: 2)

      configuration = Hailstorm::Support::Configuration.new
      digest1 = configuration.serial_version

      write_jtl('c')
      digest2 = configuration.serial_version

      expect(digest1).to_not eq(digest2)
    end

    it 'should change if the configuration file is modified' do
      %w[a b].each(&method(:write_jtl))
      write_configuration_file(num_lines: 2)

      configuration = Hailstorm::Support::Configuration.new
      digest1 = configuration.serial_version

      write_configuration_file(num_lines: 3)
      digest2 = configuration.serial_version

      expect(digest1).to_not eq(digest2)
    end
  end
end
