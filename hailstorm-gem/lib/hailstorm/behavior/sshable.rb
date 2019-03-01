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

  # Path to identity (private key) file
  # @return [String]
  def identity_file_path
    @identity_file_path ||= if Pathname.new(self.ssh_identity).absolute?
                              self.ssh_identity
                            else
                              File.join(Hailstorm.root, Hailstorm.config_dir, identity_file_name)
                            end
  end

  # Sets read only permissions for owner of identity file
  def secure_identity_file
    File.chmod(0o400, identity_file_path)
  end

  # Checks if the identity file path is a regular file
  # @return [String]
  def identity_file_ok?
    File.file?(identity_file_path) && !File.symlink?(identity_file_path)
  end

  # Array of options to connect to a host with SSH. Pass to SSH#start
  # as *ssh_connection_spec
  def ssh_connection_spec
    [self.host_name, self.user_name, ssh_options]
  end

  # Data center default settings
  class Defaults
    SSH_PORT = 22
  end
end
