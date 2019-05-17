require 'hailstorm/behavior'

# Interface for SSH connectivity to clusters
module Hailstorm::Behavior::SSHable

  # :nocov:

  # File name (not path) of the SSH identity (private key) file
  # @return [String]
  def identity_file_name
    raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
  end

  # :nocov:

  # @return [Hash] of SSH options
  def ssh_options
    unless @ssh_options
      raise(NoMethodError, "#{self.class}#ssh_port method/attribute missing") unless self.respond_to?(:ssh_port)

      @ssh_options = { keys: identity_file_path }
      @ssh_options[:port] = self.ssh_port if self.ssh_port && self.ssh_port.to_i != Defaults::SSH_PORT
    end
    @ssh_options
  end

  # Workspace path to identity (private key) file
  # @return [String]
  def identity_file_path
    if @identity_file_path.nil?
      raise(NoMethodError, "#{self.class}#project method/attribute missing") unless self.respond_to?(:project)

      @identity_file_path = Hailstorm.workspace(self.project.project_code).identity_file_path(identity_file_name)
    end

    @identity_file_path
  end

  # Sets read only permissions for owner of identity file
  def secure_identity_file(file_path)
    File.chmod(0o400, file_path)
  end

  # Transfers the identity file to workspace. Adds ActiveRecord::Error on ssh_identity if transfer fails.
  def identity_file_ok
    transfer_identity_file
  rescue Errno::ENOENT => not_found
    logger.debug(not_found.backtrace.join("\n"))
    errors.add(:ssh_identity, not_found.message)
  end

  # Array of options to connect to a host with SSH. Pass to SSH#start
  # as *ssh_connection_spec
  def ssh_connection_spec
    [self.host_name, self.user_name, ssh_options]
  end

  def transfer_identity_file
    raise(NoMethodError, "#{self.class}#ssh_identity method/attribute missing") unless self.respond_to?(:ssh_identity)

    path = Hailstorm.workspace(self.project.project_code).identity_file_path(identity_file_name)
    return path if File.exist?(path)

    if Pathname.new(self.ssh_identity).absolute?
      file_path = self.ssh_identity
      file_name = File.basename(file_path)
    else
      file_path = identity_file_name
      file_name = file_path
    end

    Hailstorm.fs.read_identity_file(file_path, self.project.project_code) do |io|
      Hailstorm.workspace(self.project.project_code).write_identity_file(file_name, io)
    end

    secure_identity_file(path)
    path
  end

  # Data center default settings
  class Defaults
    SSH_PORT = 22
  end
end
