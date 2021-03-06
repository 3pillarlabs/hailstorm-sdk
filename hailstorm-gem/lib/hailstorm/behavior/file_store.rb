# frozen_string_literal: true

require 'hailstorm/behavior'

# Abstract filesystem
module Hailstorm::Behavior::FileStore
  # :nocov:

  # Export a report
  #
  # @param [String] _project_code
  # @param [String] _local_path
  # @return [String] URI to exported resource
  def export_report(_project_code, _local_path)
    raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
  end

  # File methods for JMeter services
  module JMeter

    # Fetch JMeter plan names. Each name is the file name (without suffix) relative to the
    # application directory.
    #
    # @param [String] _project_code
    # @return [Array<String>] Array of names.
    def fetch_jmeter_plans(_project_code)
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end

    # @param [String] _project_code
    # @return [Hash] hierarchical directory structure
    def app_dir_tree(_project_code, *_args)
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end

    # All files for running tests
    # @param [String] _project_code
    # @param [String] _to_path absolute path to local filesystem
    def transfer_jmeter_artifacts(_project_code, _to_path)
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end

    # Override this file if the file_path to a test plan or data file should be altered
    # before persistence. The default is to not make any modifications.
    def normalize_file_path(file_path)
      file_path
    end
  end

  # File methods for ExecutionCycle
  module ExecutionCycle

    # Exports the JTL files (results) of an execution cycle
    #
    # @param [String] _project_code
    # @param [String] _abs_jtl_path absolute path to JTL directory or zip file on local file system
    def export_jtl(_project_code, _abs_jtl_path)
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end

    # Copies a JTL file to the given path.
    # copy_jtl(project_code, from_path:, to_path:)
    #
    # @param [String] _project_code
    # @return [String] path to copied file
    def copy_jtl(_project_code, *_args)
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end
  end

  # For SSH
  module SSHable

    # Opens the identity file for reading. If path to identity file is absolute, project_code is
    # not needed. The implementation must not assume that if a project_code is provided, the path
    # will be absolute. If a block is given, the file object is yielded, else returned.
    # @param [String] _file_path
    # @param [String] _project_code
    # @return [IO]
    def read_identity_file(_file_path, _project_code = nil)
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end
  end

  include JMeter
  include ExecutionCycle
  include SSHable

  # :nocov:
end
