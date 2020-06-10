require 'hailstorm/initializer'

# Creates the structure for a project
class Hailstorm::Initializer::ProjectStructure

  attr_reader :invocation_path, :arg_app_name, :quiet, :gems

  def initialize(invocation_path, arg_app_name, quiet, gems)
    @invocation_path = invocation_path
    @arg_app_name = arg_app_name
    @quiet = quiet
    @gems = gems
  end

  def create_app_structure
    create_root_path
    create_top_level_dirs
    create_gemfile
    create_hailstorm_script
    config_environment
    config_db
    config_initializers
    config_boot

    emit
    emit 'Done!'

    root_path
  end

  private

  def root_path
    @root_path ||= File.join(self.invocation_path, self.arg_app_name)
  end

  def create_root_path
    FileUtils.mkpath(root_path)
    emit "(in #{invocation_path})"
    emit "  created directory: #{arg_app_name}"
  end

  def skeleton_path
    @skeleton_path ||= File.join(Hailstorm.templates_path, 'skeleton')
  end

  # create directory structure
  def create_top_level_dirs
    dirs = Hailstorm.project_directories
    dirs.each do |dir|
      FileUtils.mkpath(File.join(root_path, dir))
      emit "    created directory: #{File.join(arg_app_name, dir)}"
    end
  end

  # Process Gemfile - add additional platform specific gems
  def create_gemfile
    engine = ActionView::Base.new
    engine.assign(gems: gems)
    File.open(File.join(root_path, 'Gemfile'), 'w') do |f|
      f.print(engine.render(file: File.join(skeleton_path, 'Gemfile')))
    end
    emit "    wrote #{File.join(arg_app_name, 'Gemfile')}"
  end

  # Copy to script/hailstorm
  def create_hailstorm_script
    hailstorm_script = File.join(root_path, Hailstorm.script_dir, 'hailstorm')
    FileUtils.copy(File.join(skeleton_path, 'hailstorm'), hailstorm_script)
    FileUtils.chmod(0o775, hailstorm_script) # make it executable
    emit "    wrote #{File.join(arg_app_name, Hailstorm.script_dir, 'hailstorm')}"
  end

  # Copy to config/environment.rb
  def config_environment
    FileUtils.copy(File.join(skeleton_path, 'environment.rb'), File.join(root_path, Hailstorm.config_dir))
    emit "    wrote #{File.join(arg_app_name, Hailstorm.config_dir, 'environment.rb')}"
  end

  # Copy to config/database.properties
  def config_db
    FileUtils.copy(File.join(skeleton_path, 'database.properties'),
                   File.join(root_path, Hailstorm.config_dir))
    emit "    wrote #{File.join(arg_app_name, Hailstorm.config_dir, 'database.properties')}"
  end

  # Process to config/boot.rb
  def config_boot
    engine = ActionView::Base.new
    engine.assign(app_name: arg_app_name)
    File.open(File.join(root_path, Hailstorm.config_dir, 'boot.rb'), 'w') do |f|
      f.print(engine.render(file: File.join(skeleton_path, 'boot')))
    end
    emit "    wrote #{File.join(arg_app_name, Hailstorm.config_dir, 'boot.rb')}"
  end

  def emit(message = '')
    puts message unless quiet
  end

  # Copy to config
  def config_initializers
    %w[progressive].each do |initializer|
      FileUtils.copy(File.join(skeleton_path, "#{initializer}.rb"), File.join(root_path, Hailstorm.config_dir))
      emit "    wrote #{File.join(arg_app_name, Hailstorm.config_dir, "#{initializer}.rb")}"
    end
  end
end
