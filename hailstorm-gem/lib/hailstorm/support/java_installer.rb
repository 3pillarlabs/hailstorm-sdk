require 'hailstorm/support'

# Strategy for installation of Java, assuming a Debian based OS
class Hailstorm::Support::JavaInstaller

  # Create the installer with appropriate installer class.
  # @param [Symbol] id installer to use
  def self.create(id = :trusty)
    "#{self}::#{id.to_s.camelize}".constantize.new
  end

  # Module with supported installation methods
  module AbstractInstaller

    # Yields one instruction at a time. Override to completely handle the installation.
    def install(&_block)
      instructions.each do |instr|
        yield sudo? ? sudoize(instr) : instr
      end
    end

    # Prepends sudo to every instruction including piped commands
    def sudoize(instr)
      instr.split(/\|/).collect(&:strip).collect { |x| "sudo #{x}" }.join(' | ')
    end

    # List of instructions to be executed to install Java
    def instructions
      []
    end

    def sudo?
      false
    end

    # Sets attributes as instance attributes. If the concrete installer needs instance values, call this method
    # with an attribute Hash. The attribute keys become the instance variables.
    # @param [Hash] attrs
    def attributes!(attrs)
      attrs.each_pair do |key, value|
        self.instance_variable_set("@#{key}".to_sym, value)
      end
    end
  end

  # For Ubuntu Trusty
  class Trusty
    include AbstractInstaller

    def instructions
      [
        'echo "deb http://ppa.launchpad.net/webupd8team/java/ubuntu trusty main" | \
  tee /etc/apt/sources.list.d/webupd8team-java.list',
        'echo "deb-src http://ppa.launchpad.net/webupd8team/java/ubuntu trusty main" | \
  tee -a /etc/apt/sources.list.d/webupd8team-java.list',
        'apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys EEA14886',
        'echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | /usr/bin/debconf-set-selections',
        'apt-get update',
        'apt-get install -y oracle-java8-installer oracle-java8-set-default'
      ]
    end

    def sudo?
      true
    end
  end
end
