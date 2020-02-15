# Extensions to File
class File

  # Removes the extension from a file name.
  # @param [String] file_name
  # @return [String]
  def self.strip_ext(file_name)
    ext = File.extname(file_name)
    file_name.gsub(ext, '')
  end
end
