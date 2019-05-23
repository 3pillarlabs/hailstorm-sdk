require 'hailstorm'

# clear project's tmp dir
Dir["#{Hailstorm.tmp_path}/*"].each do |e|
  File.directory?(e) ? FileUtils.rmtree(e) : File.unlink(e)
end
