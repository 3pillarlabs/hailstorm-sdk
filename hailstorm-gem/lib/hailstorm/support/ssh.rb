require 'net/ssh'
require 'net/sftp'
require 'hailstorm/support'
require 'hailstorm/behavior/loggable'
require 'hailstorm/behavior/ssh_connection'

# SSH support for Hailstorm
# @author Sayantam Dey
class Hailstorm::Support::SSH

  include Hailstorm::Behavior::Loggable

  # Starts a new SSH connection. When a block is provided, the connection
  # is closed when the block terminates, otherwise the connection will be
  # returned.
  # @param [String] host host_name or ip_address
  # @param [String] user SSH user_name
  # @param [Hash] options connection options, same as used by Net::SSH
  # @return [Net::SSH::Connection::Session] with
  #   Hailstorm::Support::SSH::ConnectionSessionInstanceMethods added
  def self.start(host, user, options = {})
    logger.debug { "#{self}.#{__method__}" }
    ssh_options = { user_known_hosts_file: '/dev/null' }.merge(options)
    if block_given?
      Net::SSH.start(host, user, ssh_options) do |ssh|
        yield extend_ssh(ssh)
      end
    else
      ssh = Net::SSH.start(host, user, ssh_options)
      extend_ssh(ssh)
    end
  end

  def self.extend_ssh(ssh)
    ssh.extend(ConnectionSessionInstanceMethods)
    ssh.logger = logger
    ssh
  end

  # Waits till the SSH connection is available; this does not wait indefinitely,
  # rather makes at max 5 attempts to connect and waits for an exponential time
  # between each successive request.
  # @param [String] host host_name or ip_address
  # @param [String] user SSH user_name
  # @param [Hash] options connection options, same as used by Net::SSH
  # @return [Boolean] true if connection was finally obtained, false otherwise
  def self.ensure_connection(host, user, options = {})
    logger.debug { "#{self}.#{__method__}" }
    connection_obtained = false
    max_tries = options[:max_tries] || 3
    num_tries = 0
    doze_time = options[:doze_time] || 1
    while num_tries < max_tries
      begin
        self.start(host, user, options) do |ssh|
          ssh.exec!('ls')
          connection_obtained = true
        end
        break
      rescue Errno::ECONNREFUSED, Net::SSH::ConnectionTimeout
        logger.debug { "Failed #{num_tries + 1} times, trying again in #{doze_time} seconds..." }
        sleep(doze_time)
        doze_time *= 3
        num_tries += 1
      end
    end

    logger.error("Giving up after trying #{num_tries + 1} times") unless connection_obtained

    connection_obtained
  end

  # Instance methods added to Net::SSH::Connection::Session
  module ConnectionSessionInstanceMethods
    include Hailstorm::Behavior::SshConnection

    alias_method :net_ssh_exec, :exec

    #:nodoc:
    def exec(command, options = {}, &block)
      logger.debug { command }
      net_ssh_exec(command, options, &block)
    end

    # @param [String] file_path full path to file on remote system
    # @return [Boolean] true if the file exists
    def file_exists?(file_path)
      path_exists?(file_path)
    end

    def directory_exists?(dir_path)
      path_exists?(dir_path, true)
    end

    # @param [String] path path to file or directory on remote system
    # @param [Boolean] is_dir true if the path is a directory, other false (default)
    def path_exists?(path, is_dir = false)
      cmd = is_dir ? "ls -ld #{path}" : "ls #{path}"
      stderr = ''
      self.exec!(cmd) do |_channel, stream, data|
        stderr << data if stream == :stderr
      end
      stderr.blank? # ls success implies path exists, stderr will be blank
    end

    # @param [Fixnum] pid process ID of remote process
    # @return [Boolean] true if process is running
    def process_running?(pid)
      process = remote_processes.find { |p| p.pid == pid }
      process ? true : false
    end

    # Terminates the remote process by sending it SIGINT, SIGTERM and SIGKILL
    # signals. If the process terminates at a signal the next signal is not
    # tried.
    # @param [Fixnum] pid process ID of remote process
    # @param [Integer] doze_time time in seconds to wait between signals, default is 5
    def terminate_process(pid, doze_time = 5)
      signals = %i[INT TERM KILL].each
      while process_running?(pid)
        self.exec!("kill -#{signals.next} #{pid}")
        sleep(doze_time)
      end
    end

    # Similar to #terminate_process and additionally ensures any child process
    # of <tt>pid</tt> are terminated as well.
    # @param [Fixnum] pid process ID of remote process
    # @param [Integer] doze_time time in seconds to wait between signals, default is 5
    def terminate_process_tree(pid, doze_time = 5)
      child_pids = remote_processes.select { |p| p.ppid == pid }.collect(&:pid)
      child_pids.each { |cpid| terminate_process_tree(cpid) }
      terminate_process(pid, doze_time)
    end

    # Creates a directory. If directory already exists no action is taken. If
    # directory is a path, all parent directories must pre-exist, that is, it
    # does not create parent directories.
    # @param [String] directory full directory path to create.
    def make_directory(directory)
      self.exec!("mkdir #{directory}") unless directory_exists?(directory)
    end

    def upload(local, remote)
      logger.debug { "uploading... #{local} -> #{remote}" }
      self.sftp.upload!(local, remote)
    end

    def download(remote, local)
      logger.debug { "downloading... #{local} <- #{remote}" }
      self.sftp.download!(remote, local)
    end

    # Finds the process ID on remote host. If not found, nil is returned.
    # @param [String] process_name name of process to find
    # @return [Fixnum]
    def find_process_id(process_name)
      process = remote_processes.find { |p| p.cmd.include?(process_name) }
      process ? process.pid : nil
    end

    # Sends a 'ps -o pid,ppid,cmd -u $user' to remote host and compiles an
    # array of processes. Each process is an RemoteProcess with following attributes:
    # pid (process ID), ppid (parent process ID), cmd (command string).
    # @return [Array<RemoteProcess>] pid, ppid, cmd
    def remote_processes
      stdout = ''
      self.exec!("ps -o pid,ppid,cmd -u #{self.options[:user]}") do |_channel, stream, data|
        stdout << data if stream == :stdout
      end
      # Sample output:
      #  PID  PPID CMD
      # 2202  1882 /bin/sh /usr/bin/startkde
      # 2297  2202 /usr/bin/ssh-agent /usr/bin/gpg-agent --daemon --sh --write-env-file=/home/sa
      # 2298  2202 /usr/bin/gpg-agent --daemon --sh --write-env-file=/home/sayantamd/.gnupg/gpg-
      # 2301     1 /usr/bin/dbus-launch --exit-with-session /usr/bin/startkde
      # 2302     1 /bin/dbus-daemon --fork --print-pid 5 --print-address 7 --session

      @remote_processes = []
      ps_line_rexp = Regexp.compile('^(\d+)\s+(\d+)\s+(.+?)$')
      stdout.split("\n").each do |line|
        line.strip!
        next if line.blank? || line.match(/^PID/i)

        matcher = ps_line_rexp.match(line)
        process = RemoteProcess.new(pid: matcher[1], ppid: matcher[2], cmd: matcher[3])
        @remote_processes.push(process)
      end

      @remote_processes
    end
  end

  # Remote process. This is an internal class.
  class RemoteProcess

    MEMBERS = %i[pid ppid cmd].freeze

    attr_reader(*MEMBERS)

    def initialize(pid:, ppid:, cmd:)
      @pid = pid.to_i
      @ppid = ppid.to_i
      @cmd = cmd
    end

    def to_h
      @to_h ||= MEMBERS.reduce({}) { |s, m| s.merge(m.to_sym => self.send(m)) }
    end
  end
end
