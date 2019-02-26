require 'hailstorm/support'
require 'hailstorm/behavior/loggable'

# File helper methods
class Hailstorm::Support::FileHelper
  include Hailstorm::Behavior::Loggable

  GZ_READ_LEN_BYTES = 2 * 1024 * 1024 # 2MB

  # Instance methods. Module enables use of helper as a mixed-in module and a class.
  module InstanceMethods
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

    # Same as gzip -d <gzip_file_path>
    # @param [String] gzip_file_path
    # @param [String] file_path
    # @param [Boolean] unlink_gzip remove gzip file after gunzip, default behavior is to keep the file
    def gunzip_file(gzip_file_path, file_path, unlink_gzip = false)
      File.open(gzip_file_path, 'r') do |compressed|
        File.open(file_path, 'w') do |uncompressed|
          gz = Zlib::GzipReader.new(compressed)
          until ((bytes = gz.read(GZ_READ_LEN_BYTES))).nil?
            uncompressed.print(bytes)
          end
          gz.close
        end
      end
      File.unlink(gzip_file_path) if unlink_gzip
    end
  end

  include InstanceMethods
end
