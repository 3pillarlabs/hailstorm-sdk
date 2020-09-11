# frozen_string_literal: true

require 'hailstorm/support'
require 'hailstorm/behavior/loggable'
require 'zip/filesystem'

# File helper methods
class Hailstorm::Support::FileHelper
  include Hailstorm::Behavior::Loggable

  GZ_READ_LEN_BYTES = 2 * 1024 * 1024 # 2MB

  # Instance methods. Module enables use of helper as a mixed-in module and a class.
  module InstanceMethods

    # Same as gzip -d <gzip_file_path>
    # @param [String] gzip_file_path
    # @param [String] file_path
    # @param [Boolean] unlink_gzip remove gzip file after gunzip, default behavior is to remove the file
    def gunzip_file(gzip_file_path, file_path, unlink_gzip: true)
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

    # Same as zip -o out_file dir/
    # @param [String] dir_path
    # @param [String] output_file_path
    # @param [Array<String>] patterns
    def zip_dir(dir_path, output_file_path, patterns: nil)
      rexp = Regexp.compile("#{dir_path}/")
      patterns ||= [File.join(dir_path, '**', '*')]

      Zip::File.open(output_file_path, Zip::File::CREATE) do |zipfile|
        Dir[*patterns].sort.each do |entry|
          zip_entry = entry.gsub(rexp, '')
          if File.directory?(entry)
            zipfile.mkdir(zip_entry)
          else
            zipfile.add(zip_entry, entry) { true }
          end
        end
      end
    end
  end

  include InstanceMethods
end
