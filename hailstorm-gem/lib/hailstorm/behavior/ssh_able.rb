require 'hailstorm/behavior'

# Interface for SSH connectivity to clusters
module Hailstorm::Behavior::SSHAble

  # :nocov:

  # Implement this method to return a Hash of options that are processed by
  # Net::SSH. Default is to return an empty Hash.
  # @return [Hash]
  def ssh_options
    {} # override and do something appropriate.
  end

  # :nocov:

end
