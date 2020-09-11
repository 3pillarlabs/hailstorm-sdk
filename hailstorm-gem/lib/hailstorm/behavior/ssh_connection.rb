# frozen_string_literal: true

require 'hailstorm/behavior'

# SSH connection
module Hailstorm::Behavior::SshConnection
  attr_accessor :logger

  # This is a stub. Used for indexing and helping verifying doubles to assert that this method exists
  # while stubbing behavior.
  def net_ssh_exec(*)
    # :nocov:
    raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    # :nocov:
  end

  # This is a stub. Used for indexing and helping verifying doubles to assert that this method exists
  # while stubbing behavior.
  def exec(*)
    super
  end

  # This is a stub. Used for indexing and helping verifying doubles to assert that this method exists
  # while stubbing behavior.
  def exec!(*)
    super
  end

  # @param [String] _file_path full path to file on remote system
  # @return [Boolean] true if the file exists
  def file_exists?(_file_path)
    # :nocov:
    raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    # :nocov:
  end

  # @param [String] _dir_path full path to directory on remote system
  # @return [Boolean] true if the directory exists
  def directory_exists?(_dir_path)
    # :nocov:
    raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    # :nocov:
  end

  # @param [String] _path path to file or directory on remote system
  # @param [Boolean] is_dir true if the path is a directory, other false (default)
  def path_exists?(_path, is_dir: false)
    # :nocov:
    raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    # :nocov:
  end

  # @param [Fixnum] _pid process ID of remote process
  # @return [Boolean] true if process is running
  def process_running?(_pid)
    # :nocov:
    raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    # :nocov:
  end

  # Terminates the remote process by sending it SIGINT, SIGTERM and SIGKILL
  # signals. If the process terminates at a signal the next signal is not
  # tried.
  # @param [Fixnum] _pid process ID of remote process
  # @param [Integer] _doze_time time in seconds to wait between signals, default is 5
  def terminate_process(_pid, _doze_time = 5)
    # :nocov:
    raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    # :nocov:
  end

  # Similar to #terminate_process and additionally ensures any child process
  # of <tt>pid</tt> are terminated as well.
  # @param [Fixnum] _pid process ID of remote process
  # @param [Integer] _doze_time time in seconds to wait between signals, default is 5
  def terminate_process_tree(_pid, _doze_time = 5)
    # :nocov:
    raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    # :nocov:
  end

  # Creates a directory. If directory already exists no action is taken. If
  # directory is a path, all parent directories must pre-exist, that is, it
  # does not create parent directories.
  # @param [String] _directory full directory path to create.
  def make_directory(_directory)
    # :nocov:
    raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    # :nocov:
  end

  def upload(_local, _remote)
    # :nocov:
    raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    # :nocov:
  end

  def download(_remote, _local)
    # :nocov:
    raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    # :nocov:
  end

  # Finds the process ID on remote host. If not found, nil is returned.
  # @param [String] _process_name name of process to find
  # @return [Fixnum]
  def find_process_id(_process_name)
    # :nocov:
    raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    # :nocov:
  end

  # Sends a 'ps -o pid,ppid,cmd -u $user' to remote host and compiles an
  # array of processes. Each process is an RemoteProcess with following attributes:
  # pid (process ID), ppid (parent process ID), cmd (command string).
  # @return [Array<RemoteProcess>] pid, ppid, cmd
  def remote_processes
    # :nocov:
    raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    # :nocov:
  end
end
