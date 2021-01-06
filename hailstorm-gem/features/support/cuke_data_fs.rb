# frozen_string_literal: true

require 'hailstorm/behavior/file_store'

# FileStore implementation for integration tests
class CukeDataFs
  include Hailstorm::Behavior::FileStore

  JMX_PATH = File.expand_path('../../data/hailstorm-site-basic.jmx', __FILE__)

  attr_writer :jtl_path
  attr_reader :report_path

  def fetch_jmeter_plans(*_args)
    ['hailstorm-site-basic']
  end

  def app_dir_tree(*_args)
    { data: nil }.stringify_keys
  end

  def transfer_jmeter_artifacts(_project_code, to_dir_path)
    FileUtils.cp(JMX_PATH, "#{to_dir_path}/hailstorm-site-basic.jmx")
  end

  def copy_jtl(_project_code, from_path:, to_path:)
    jtl_file = File.basename(@jtl_path)
    copied_path = "#{to_path}/#{jtl_file}"
    FileUtils.cp(@jtl_path, copied_path)
    copied_path
  end

  def export_report(_project_code, local_path)
    file_name = File.basename(local_path)
    export_path = File.expand_path('../../../build', __FILE__)
    @report_path = File.join(export_path, file_name)
    FileUtils.cp(local_path, @report_path)
  end
end
