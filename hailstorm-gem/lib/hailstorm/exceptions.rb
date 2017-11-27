module Hailstorm

  # Subclass or use this for exceptions in workflow
  class Exception < StandardError
  end

  # Exception for threading issues.
  class ThreadJoinException < Exception

    # @param [Array] exceptions
    def initialize(exceptions)
      @exceptions = exceptions
    end

    def message
      @message ||= @exceptions.nil? ? super.message : @exceptions.collect(&:message)
    end
  end

  # Exceptions that provide diagnostic messages to help troubleshoot issues.
  class DiagnosticAwareException < Exception
    def message
      @message ||= diagnostics.gsub(/[ \t]{2,}/, ' ').freeze
    end

    def diagnostics
      ''
    end
  end

  # Incompatible configuration
  class MasterSlaveSwitchOnConflict < DiagnosticAwareException
    def diagnostics
      %(You have switched ON master slave mode in the middle of a test
        execution. The current setup is no longer valid. Please 'terminate'
        current cycle first and 'setup' again.)
    end
  end

  # Incompatible configuration
  class MasterSlaveSwitchOffConflict < DiagnosticAwareException
    def diagnostics
      %(You have switched OFF master slave mode in the middle of a test
        execution. The current setup is no longer valid. Please 'terminate'
        current cycle first and 'setup' again.)
    end
  end

  # Agent could not be created
  class AgentCreationFailure < DiagnosticAwareException
    def diagnostics
      %(One or more agents could not be prepared for load generation.
        This can happen due to issues in your cluster(Amazon or data-center)
        or a misconfiguration. Try 'setup force'.)
    end
  end

  # JMeter installation problem
  class JMeterVersionNotFound < DiagnosticAwareException

    attr_reader :jmeter_version, :bucket_name, :jmeter_file_path

    # @param [Object] jmeter_version
    # @param [String] bucket_name
    # @param [String] jmeter_file_path
    def initialize(jmeter_version, bucket_name, jmeter_file_path)
      @jmeter_version = jmeter_version
      @bucket_name = bucket_name
      @jmeter_file_path = jmeter_file_path
    end

    def diagnostics
      %(The JMeter version '#{jmeter_version}' from '#{jmeter_file_path}' specified in
        [config/environment.rb] cannot be installed. If you would like to use
        a custom JMeter package, make sure the associated {VERSION}.tgz file is
        uploaded to Amazon S3 bucket '#{bucket_name}'. If you are unsure,
        remove the jmeter_version property.)
    end
  end

  # Issues with AMI creation
  class AmiCreationFailure < DiagnosticAwareException

    attr_reader :region, :reason

    # @param [String] region
    # @param [Object] reason AWS::EC2::Image#state_reason
    def initialize(region, reason)
      @region = region
      @reason = reason
    end

    def diagnostics
      %(AMI could not be created in AWS region '#{region}'. The failure reason
        from Amazon is #{reason ? "[#{reason.code}] #{reason.message}" : 'unknown'}. The Amazon services for the
        affected region may be down. You can try the 'setup force' command. If the problem persists, report the issue.)
    end
  end

  # Data center issues
  class DataCenterAccessFailure < DiagnosticAwareException

    attr_reader :agent_machine, :user_name, :ssh_identity

    # @param [String] user_name  ssh user name
    # @param [String] agent_machines comma separated ip addresses of machines
    # @param [String] ssh_identity ssh ssh identity
    def initialize(user_name, agent_machines, ssh_identity)
      @agent_machine = agent_machines
      @user_name    = user_name
      @ssh_identity = ssh_identity
    end

    def diagnostics
      %(HailStorm is not able to connect to agent##{agent_machine} using user name '#{user_name}'
      and ssh identity file '#{ssh_identity}'. System might not be running at the moment or
      user and/or ssh identity used are not allowed to connect to specified machine.)
    end
  end

  # Java on Data center
  class DataCenterJavaFailure < DiagnosticAwareException
    attr_reader :java_version
    # @param [String] java_version
    def initialize(java_version)
      @java_version = java_version
    end

    def diagnostics
      %(Either Java is not installed or required version '#{java_version}' is not available
      on one of the machines specified. Please make sure:
      1\) Required Java/JRE version is installed
      2\) JAVA_HOME/JRE_HOME and required path variable are set and accessible)
    end
  end

  # JMeter on Data center
  class DataCenterJMeterFailure < DiagnosticAwareException
    attr_reader :jmeter_version
    # @param [String] jmeter_version
    def initialize(jmeter_version)
      @jmeter_version = jmeter_version
    end

    def diagnostics
      %(Either JMeter is not installed or required version '#{jmeter_version}' is not available
      on one of one of the machines specified. Please make sure:
      1\) Required JMeter version is installed
      2\) JMETER_HOME and required path variable are set and accessible)
    end
  end

  # Java installation issues
  class JavaInstallationException < AmiCreationFailure

    def initialize(region, reason)
      @region = region
      @reason = reason
    end

    def diagnostics
      %(Hailstorm cannot install JRE from the configured installer on region #{@region}: #{@reason})
    end
  end

end
