require 'hailstorm/behavior'

# SSH connection
module Hailstorm::Behavior::SshConnection
  # :nocov:
  attr_accessor :logger

  def net_ssh_exec(*)
    raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
  end

  def exec(*)
    raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
  end

  def exec!(*)
    raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
  end

  # @param [String] file_path full path to file on remote system
  # @return [Boolean] true if the file exists
  def file_exists?(file_path)
    raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
  end

  # @param [String] dir_path full path to directory on remote system
  # @return [Boolean] true if the directory exists
  def directory_exists?(dir_path)
    raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
  end

  # @param [String] path path to file or directory on remote system
  # @param [Boolean] is_dir true if the path is a directory, other false (default)
  def path_exists?(path, is_dir = false)
    raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
  end

  # @param [Fixnum] pid process ID of remote process
  # @return [Boolean] true if process is running
  def process_running?(pid)
    raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
  end

  # Terminates the remote process by sending it SIGINT, SIGTERM and SIGKILL
  # signals. If the process terminates at a signal the next signal is not
  # tried.
  # @param [Fixnum] pid process ID of remote process
  # @param [Integer] doze_time time in seconds to wait between signals, default is 5
  def terminate_process(pid, doze_time = 5)
    raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
  end

  # Similar to #terminate_process and additionally ensures any child process
  # of <tt>pid</tt> are terminated as well.
  # @param [Fixnum] pid process ID of remote process
  # @param [Integer] doze_time time in seconds to wait between signals, default is 5
  def terminate_process_tree(pid, doze_time = 5)
    raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
  end

  # Creates a directory. If directory already exists no action is taken. If
  # directory is a path, all parent directories must pre-exist, that is, it
  # does not create parent directories.
  # @param [String] directory full directory path to create.
  def make_directory(directory)
    raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
  end

  def upload(local, remote)
    raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
  end

  def download(remote, local)
    raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
  end

  # Finds the process ID on remote host. If not found, nil is returned.
  # @param [String] process_name name of process to find
  # @return [Fixnum]
  def find_process_id(process_name)
    raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
  end

  # Sends a 'ps -o pid,ppid,cmd -u $user' to remote host and compiles an
  # array of processes. Each process is an RemoteProcess with following attributes:
  # pid (process ID), ppid (parent process ID), cmd (command string).
  # @return [Array<RemoteProcess>] pid, ppid, cmd
  def remote_processes
    raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
  end
  # :nocov:
end
