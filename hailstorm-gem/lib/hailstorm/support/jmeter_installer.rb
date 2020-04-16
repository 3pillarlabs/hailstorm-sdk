require 'hailstorm/support'

# JMeter Installer, assumes Java is present in the system.
class Hailstorm::Support::JmeterInstaller

  # Custom JMeter installer URL patterns
  CUSTOM_JMETER_URL_REXPS = [
    Regexp.compile(/[\-_]([\d.\w]+)\.ta?r?\.?gz$/),
    Regexp.compile(/(\w+)\.ta?r?\.?gz$/)
  ].freeze

  # Create the installer with appropriate installer class.
  # @param [Symbol] id installer to use
  def self.create(id = :tarball)
    installer = self.new
    installer.extend("#{self}::#{id.to_s.camelize}".constantize)
    installer
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

    # :nocov:
    # Override to provide instructions specific to installation strategy
    def install_instructions
      []
    end
    # :nocov:

    # Override to perform checks or operations before install
    def pre_install; end

    # :nocov:
    # Override to provide the path to the JMeter installation directory
    def jmeter_home
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end
    # :nocov:
  end

  # Installation with a tarball
  module Tarball
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
        "wget '#{jmeter_download_url}' -O #{jmeter_download_file}",
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
        return
      end
      raise(ArgumentError, 'need either @jmeter_version or @download_url')
    end

    def jmeter_home
      "#{self.user_home}/jmeter"
    end

    # Installing by specifying a JMeter version
    module JmeterVersionStrategy

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

      def self.extract_jmeter_version(url)
        CUSTOM_JMETER_URL_REXPS.each do |rexp|
          match_data = rexp.match(url)
          return match_data[1] if match_data
        end
      end
    end
  end

  # Validations module
  module Validator
    JMETER_VERSION_REXP = Regexp.compile(/^(\d+)\.(\d+)/)

    # Check if the JMeter version is not lower than minimum compatible
    def self.validate_version(jmeter_version, min_major, min_minor)
      match_data = JMETER_VERSION_REXP.match(jmeter_version)
      if match_data
        major, minor = match_data[1..-1].collect(&:to_i)
        return major > min_major || (major == min_major && minor >= min_minor)
      end
      false
    end

    # Check if the URL matches allowed patterns
    def self.validate_download_url_format(url)
      CUSTOM_JMETER_URL_REXPS.each do |rexp|
        return true if rexp.match(url)
      end
      false
    end
  end
end
