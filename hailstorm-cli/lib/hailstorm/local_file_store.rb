require 'hailstorm'
require 'hailstorm/behavior/file_store'
require 'hailstorm/behavior/loggable'

# Local file system implementation of file store.
class Hailstorm::LocalFileStore
  include Hailstorm::Behavior::FileStore
  include Hailstorm::Behavior::Loggable

  def fetch_jmeter_plans(_project_code)
    file_prefix = File.join(Hailstorm.root, Hailstorm.app_dir).concat(File::SEPARATOR)
    Dir[File.join(Hailstorm.root, Hailstorm.app_dir, '**', '*.jmx')]
      .map { |n| n.split(file_prefix).last.gsub(/\.jmx$/, '') }
  end

  # pick app sub-directories
  def app_dir_tree
    tree_dir(File.join(Hailstorm.root, Hailstorm.app_dir))
  end

  # Reads directories within a start directory
  # Example:
  # a
  # |-- b
  # |-- |-- d
  # |--    |__ e
  # |__ c
  #    |__ f
  #
  # Results in:
  #  {
  #    "a" => {
  #       "b" => {
  #         "d" => { "e" => nil }
  #       },
  #       "c" => { "f" => nil }
  #    }
  #  }
  def tree_dir(start_dir, entries = {})
    queue = [[start_dir, entries]]
    entries[File.basename(start_dir)] = nil
    queue.each do |path, context|
      key = File.basename(path)
      Dir[File.join(path, '*')].select { |sub| File.directory?(sub) }.each do |sub_dir|
        context[key] = {} if context[key].nil?
        context[key][File.basename(sub_dir)] = nil
        queue.push([sub_dir, context[key]])
      end
    end
    entries
  end

  def transfer_jmeter_artifacts(_project_code, transfer_path)
    file_prefix = File.join(Hailstorm.root, Hailstorm.app_dir).concat('/')
    # Do not upload files with ~, bk, bkp, backup in extension or starting with . (hidden)
    hidden_file_rexp = Regexp.new('^\.')
    backup_file_rexp = Regexp.new('(?:~|bk|bkp|backup|old|tmp)$')
    Dir[File.join(Hailstorm.root, Hailstorm.app_dir, '**', '*')].each do |entry|
      next unless File.file?(entry)

      entry_name = File.basename(entry)
      next if hidden_file_rexp.match(entry_name) || backup_file_rexp.match(entry_name)

      rel_path = entry.split(file_prefix).last
      FileUtils.cp(entry, File.join(transfer_path, rel_path))
    end
  end

  def export_jtl(_project_code, abs_jtl_path)
    reports_path = File.join(Hailstorm.root, Hailstorm.reports_dir)
    FileUtils.rm_rf(reports_path)
    FileUtils.mkpath(reports_path)
    if File.file?(abs_jtl_path)
      export_path = File.join(reports_path, File.basename(abs_jtl_path))
      FileUtils.cp(abs_jtl_path, export_path)
    elsif File.directory?(abs_jtl_path)
      export_path = File.join(reports_path, File.basename(abs_jtl_path))
      FileUtils.mkdir(export_path)
      Dir["#{abs_jtl_path}/*"].each do |seq_path|
        FileUtils.cp_r(seq_path, File.join(export_path, File.basename(seq_path)))
      end
    end

    logger.info { "Results exported to: #{export_path}" }
  end

  def read_identity_file(file_path, _project_code = nil)
    identity_file_path = if Pathname.new(file_path).absolute?
                           file_path
                         else
                           File.join(Hailstorm.root, Hailstorm.config_dir, file_path)
                         end
    io = File.open(identity_file_path, 'r')
    if block_given?
      begin
        yield io
      ensure
        io.close
      end
    end

    io
  end

  def copy_jtl(_project_code, from_path:, to_path:)
    file_name = File.basename(from_path)
    FileUtils.cp(from_path, File.join(to_path, file_name))
  end

  def export_report(_project_code, local_path)
    file_name = File.basename(local_path)
    export_path = File.join(Hailstorm.root, Hailstorm.reports_dir)
    FileUtils.cp(local_path, File.join(export_path, file_name))
    logger.info { "Report generated to: #{export_path}" }
  end
end
