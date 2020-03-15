require 'fileutils'

require 'hailstorm/support'

# Workspace implementation for library.
class Hailstorm::Support::Workspace

  ROOT_DIR = '.hailstorm'.freeze
  WORKSPACE_DIR = 'workspace'.freeze
  KEYS_DIR = 'keys'.freeze
  TMP_DIR = 'tmp'.freeze

  # @return [String]
  attr_reader :project_code

  # @param [String] project_code
  def initialize(project_code)
    @project_code = project_code
  end

  # @param [String] file_name
  # @param [IO] io
  # @return [String] absolute path to generated file
  def write_identity_file(file_name, io)
    path = self.identity_file_path(file_name)
    File.open(path, 'w') do |out|
      out.write(io.read)
    end

    path
  end

  # @return [String] path to identity file in workspace
  def identity_file_path(file_name)
    File.join(workspace_dir_path(KEYS_DIR), file_name)
  end

  # @param [Hash] layout
  def make_app_layout(layout)
    FileUtils.mkdir_p(app_path)
    return if layout.values.last.nil?

    entries = [[app_path, layout.values.last]]
    entries.each do |parent, sub_lay|
      sub_lay.keys.each do |dir|
        FileUtils.mkdir_p(File.join(parent, dir))
        entries.push([File.join(parent, dir), sub_lay[dir]]) unless sub_lay[dir].nil?
      end
    end
  end

  # @return [String] path to app
  def app_path
    @app_path ||= workspace_dir_path(Hailstorm.app_dir)
  end

  # If a block is given, yield the IO instance associated with the app file,
  # otherwise, return it.
  #
  # @param [String] plan_rel_path relative path of the plan in the app structure
  # @return [IO]
  def open_app_file(plan_rel_path)
    io = File.open(File.join(app_path, "#{plan_rel_path}.jmx"), 'r')
    return io unless block_given?

    begin
      yield io
    ensure
      io.close
    end
  end

  # @return [String]
  def workspace_path
    @workspace_path ||= File.join(user_home,
                                  ROOT_DIR,
                                  WORKSPACE_DIR, self.project_code)
  end

  # @return [String]
  def tmp_path
    @tmp_path ||= workspace_dir_path(TMP_DIR)
  end

  # Creates a directory in the workspace temporary directory.
  #
  # @param [String] dir_name
  # @return [String] full path to directory
  def make_tmp_dir(dir_name)
    path_to_make = File.join(tmp_path, dir_name)
    FileUtils.rm_rf(path_to_make)
    FileUtils.mkdir_p(path_to_make)
    path_to_make
  end

  # @return [Array] All file paths in app directory
  def app_entries
    Dir[File.join(app_path, '**', '*')]
  end

  def purge
    [KEYS_DIR, Hailstorm.app_dir, TMP_DIR].each do |dir|
      FileUtils.rm_rf(workspace_dir_path(dir))
    end

    create_file_layout
  end

  def create_file_layout
    [KEYS_DIR, Hailstorm.app_dir, TMP_DIR].each do |dir|
      FileUtils.mkdir_p(workspace_dir_path(dir))
    end
  end

  private

  def workspace_dir_path(dir)
    File.join(workspace_path, dir)
  end

  def user_home
    @user_home ||= ENV['HOME']
  end
end
