require 'hailstorm/support'
require 'hailstorm/behavior/loggable'

# File helper methods
class Hailstorm::Support::FileHelper
  include Hailstorm::Behavior::Loggable

  # Iterator over JMeter test plans in the project app directory
  # @return [Enumerator]
  # @param [String] glob
  def dir_glob_enumerator(glob)
    Dir[glob].each
  end

  # Checks if the path exists and is a regular file
  # @param [String] path
  def file?(path)
    File.exist?(path) && File.file?(path)
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
  # @param [String] start_dir Path to a starting directory (including the directory)
  # @param [Hash] entries
  # @return [Hash] hierarchical directory structure
  def local_app_directories(start_dir, entries = {})
    logger.debug { "#{self.class}##{__method__}" }
    raise(ArgumentError, 'entries should be Hash') unless entries.is_a?(Hash)
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
end
