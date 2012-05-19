# File based array for operations on potentially very large arrays. Minimizes
# memory usage at the cost of execution speed.
#
# The array is bound to elements of the same type, much like generic collections
# in Java 5.
#
# Note that not all Array operations are supported - FileArray walks and talks
# partly like an Array.
#
# @author Sayantam Dey

require 'tmpdir'

require 'hailstorm/support'

class Hailstorm::Support::FileArray

  MAX_PAGE_LEN = 100

  # @return [Class]
  attr_reader :klass

  # @return [String]
  attr_reader :file_path

  # @return [String]
  attr_reader :tmp_path

  # @return [Array]
  attr_reader :page_file_paths

  # @return [Integer]
  attr_reader :max_page_len

  # Initializes the file array. <tt>options</tt> recognized following keys:
  #   :path - path at which the file will be created, if not mentioned, it
  #           will use the system temporary path (eg. /tmp for UNIX)
  #
  #   :max_page_len - maximum length of a single page. A page should comfortably
  #                   fit in memory
  # @param [Class] klass the class of each element
  # @param [Hash] options
  def initialize(klass, options = {})

    @klass = klass

    file_name = "fa_#{object_id}.txt"
    @tmp_path = options[:path] || Dir.tmpdir
    @file_path = File.join(@tmp_path, file_name)
    @page_file_paths = []

    @max_page_len = options[:max_page_len] || MAX_PAGE_LEN
  end

  # Performs a file sort of the contents in ascending order.
  def sort!()

    File.open(file_path, 'r') do |file| # open main file
      page_index = 0
      page_buffer = []
      file.each_line do |line|
        line.chomp!
        element = type_convert(line)
        if page_buffer.length < self.max_page_len
          page_buffer.push(element)
        else
          page_file_creator(page_index) do |page_file|
            page_buffer.sort.each do |element|
              page_file.puts(element)
            end
          end
          page_index += 1
          page_buffer.clear()
          page_buffer.push(element) # push the element that was read
        end
      end

      # take care of last page_buffer
      unless page_buffer.empty?
        page_file_creator(page_index) do |page_file|
          page_buffer.sort.each do |element|
            page_file.puts(element)
          end
        end
      end
    end

    # merge the files into a single file after comparison of elements
    page_files = nil
    begin
      File.open(file_path, 'w') do |file|

        min = nil
        until min == :done
          # open all page files
          page_files = self.page_file_paths
                           .collect {|page_file| File.open(page_file, 'r')}

          page_index = 0
          page_files.each_with_index do |page_file, index|
            unless page_file.eof?
              line = page_file.readline() # read first line of file
              line.chomp!
              element = type_convert(line)
              if min.nil? or min > element
                min = element
                page_index = index
              end
            end
          end
          page_files.each {|page_file| page_file.close()}

          unless min.nil? # will be nil when all page_files are exhausted
            # write min out to file
            file.puts(min)

            # shift up the page_file at page_index
            page_buffer = []
            # read entries
            File.open(self.page_file_paths[page_index], 'r') do |page_file|
              page_file.each_line do |line|
                line.chomp!
                page_buffer.push(type_convert(line))
              end
            end

            page_buffer.shift() # lose the first element

            # write back remaining entries
            File.open(self.page_file_paths[page_index], 'w') do |page_file|
              page_buffer.each {|e| page_file.puts(e) }
            end

            min = nil # reset min
          else
            min = :done
          end
        end
      end

    ensure
      # unlink all page files
      page_files.each {|page_file| File.unlink(page_file.path)} unless page_files.nil?
    end

  end

  # Returns the element at the given index. For Ruby types, the element will
  # be converted to correct type before returning.
  # Negative indexing is not supported (will return nil)
  # @param [Integer] index
  # @return [Object] element
  def [](index)

    element = nil
    if index >= 0
      File.open(file_path, 'r') do |file|
        line_index = 0
        file.each_line do |line|
          line.chomp!
          if line_index == index
            element = type_convert(line)
            break
          end
          line_index += 1
        end
      end
    end

    return element
  end

  # Pushes the element into the array.
  # @param [Object] element
  # @raise [ArgumentException] if element class is different from initialized
  #                            klass
  def push(element)

    unless element.class == self.klass
      raise(ArgumentError, "element class (#{element.class}) not same as specified in initializer (#{klass})")
    end
    File.open(file_path, 'a') do |file|
      file.puts(element)
    end
  end

  # Destroys the file.
  def unlink()
    File.unlink(file_path) if File.exists?(file_path)
  end

  def each(&block)
    File.open(self.file_path, 'r') do |file|
      file.each_line do |line|
        line.chomp!
        element = type_convert(line)
        yield element
      end
    end
  end

  private

  def type_convert(line)

    case self.klass.name
      when Fixnum.name
        element = line.to_i
      when Float.name
        element = line.to_f
      else
        element = line.to_s
    end
    element
  end

  def page_file_creator(index, &block)

    file_path = File.join(tmp_path, "fa_#{object_id}_page_#{index}.txt")
    File.open(file_path, 'w') do |file|
      yield file
    end

    self.page_file_paths.push(file_path)
  end

end
