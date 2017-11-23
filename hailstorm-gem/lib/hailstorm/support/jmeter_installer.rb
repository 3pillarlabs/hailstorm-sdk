# JMeter Installer, assumes Java is present in the system.
class Hailstorm::Support::JmeterInstaller

  # Create the installer with appropriate installer class.
  # @param [Symbol] id installer to use
  def self.create(id = :tarball)
    "#{self}::#{id.to_s.camelize}".constantize.new
  end

  # Installer abstraction that creates an uniform interface
  module AbstractInstaller

    # Sets the attribute value on the current object. The current object must have <tt>attr_writer</tt> with the
    # attribute name
    # @param [Symbol] attribute
    # @param [Object] value
    # @return self current object
    def with(attribute, value)
      self.send("#{attribute}=", value)
      self
    end

    # Default implementation yields one instruction at a time. Override if needed for a different strategy
    def install(&_block)
      pre_install
      instructions.each { |e| yield e }
    end

    # Adds post-installation settings
    def instructions
      jmeter_properties_path = "#{jmeter_home}/bin/user.properties"
      install_instructions.push(
        "echo '# Added by Hailstorm' >> #{jmeter_properties_path}",
        "echo 'jmeter.save.saveservice.output_format=xml' >> #{jmeter_properties_path}",
        "echo 'jmeter.save.saveservice.hostname=true' >> #{jmeter_properties_path}",
        "echo 'jmeter.save.saveservice.thread_counts=true' >> #{jmeter_properties_path}",
        "echo '# End of additions by Hailstorm' >> #{jmeter_properties_path}"
      )
    end

    # Override to provide instructions specific to installation strategy
    def install_instructions
      []
    end

    # Override to perform checks or operations before install
    def pre_install; end

    # Override to provide the path to the JMeter installation directory
    def jmeter_home
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end
  end

  # Installation with a tarball
  class Tarball
    include AbstractInstaller

    attr_accessor :download_url

    attr_accessor :user_home

    attr_reader :jmeter_version

    def jmeter_version=(new_jmeter_version)
      @jmeter_version = new_jmeter_version.to_s unless new_jmeter_version.nil?
    end

    # Instructions for installation from a tarball
    def install_instructions
      [
        "wget -q '#{jmeter_download_url}' -O #{jmeter_download_file}",
        "tar -xzf #{jmeter_download_file}",
        "ln -s #{user_home}/#{jmeter_directory} #{user_home}/jmeter"
      ]
    end

    # (see AbstractInstaller#pre_install)
    def pre_install
      if download_url
        self.extend(DownloadUrlStrategy)
        return
      end
      if jmeter_version
        self.extend(JmeterVersionStrategy)
        validate_version
        return
      end
      raise(ArgumentError, 'need either @jmeter_version or @download_url')
    end

    def jmeter_home
      "#{self.user_home}/jmeter"
    end

    # Installing by specifying a JMeter version
    module JmeterVersionStrategy

      MIN_MAJOR = 2
      MIN_MINOR = 5
      JMETER_VERSION_REXP = Regexp.compile(/^(\d+)\.(\d+)/)

      # Check if the JMeter version is not lower than minimum compatible (2.6)
      def validate_version
        match_data = JMETER_VERSION_REXP.match(jmeter_version)
        if match_data
          major, minor = match_data[1..-1].collect(&:to_i)
          return if major > MIN_MAJOR || (major == MIN_MAJOR && minor > MIN_MINOR)
        end
        raise(ArgumentError, "Incorrect JMeter version: #{jmeter_version}")
      end

      def jmeter_download_url
        "https://archive.apache.org/dist/jmeter/binaries/#{jmeter_download_file}"
      end

      def jmeter_download_file
        "#{jmeter_directory}.tgz"
      end

      def jmeter_directory
        "apache-jmeter-#{jmeter_version}"
      end
    end

    # Installing by downloading from a specified URL
    module DownloadUrlStrategy

      JMETER_DIR_REXP = Regexp.compile(/^(.+?)\.ta?r?\.?gz$/)

      def jmeter_download_url
        download_url
      end

      def jmeter_download_file
        File.basename(URI(self.download_url).path)
      end

      def jmeter_directory
        JMETER_DIR_REXP =~ jmeter_download_file && Regexp.last_match(1)
      end
    end
  end
end
