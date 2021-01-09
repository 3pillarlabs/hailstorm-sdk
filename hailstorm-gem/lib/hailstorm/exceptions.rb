# frozen_string_literal: true

module Hailstorm

  # An exception class should include this module if it represents a temporary failure that should be retried.
  module TemporaryFailure

    # Indicates the number of milliseconds a client should wait before trying again.
    # Override this to increase or decrease the advised time.
    DEFAULT_RETRY_WAIT_MS = 3000

    attr_writer :retry_after_ms

    def retry_after_ms
      @retry_after_ms ||= DEFAULT_RETRY_WAIT_MS
    end

    def retryable?
      true
    end
  end

  # Subclass or use this for exceptions in workflow
  class Exception < StandardError
    include TemporaryFailure

    attr_writer :retryable

    def initialize(msg = nil)
      super
      @retryable = false
    end

    def retryable?
      @retryable
    end
  end

  # Exception for threading issues.
  class ThreadJoinException < Exception

    attr_reader :exceptions

    # @param [Array] exceptions
    def initialize(exceptions = [])
      super

      @exceptions = exceptions.is_a?(Array) ? exceptions : [exceptions]
    end

    def message
      @message ||= exceptions.empty? ? super.message : exceptions.collect(&:message).join("\n")
    end
  end

  # Exception for unknown command
  class UnknownCommandException < Exception
  end

  # Exception for unknown options to a command
  class UnknownCommandOptionException < Exception
  end

  # Exceptions that provide diagnostic messages to help troubleshoot issues.
  class DiagnosticAwareException < Exception
    def message
      @message ||= diagnostics.gsub(/[ \t]{2,}/, ' ').freeze
    end

    # :nocov:
    def diagnostics
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end
    # :nocov:
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
    include TemporaryFailure

    def diagnostics
      %(One or more agents could not be prepared for load generation.
        This can happen due to issues in your cluster(Amazon or data-center)
        or a misconfiguration. Try 'setup force'.)
    end
  end

  # Issues with AMI creation
  class AmiCreationFailure < DiagnosticAwareException
    include TemporaryFailure

    attr_reader :region, :reason
    attr_writer :retryable

    # @param [String] region
    # @param [Struct] reason reason(code, message)
    def initialize(region, reason)
      super()

      @region = region
      @reason = reason
      @retryable = false
    end

    def diagnostics
      %(AMI could not be created in AWS region '#{region}'. The failure reason
        from Amazon is #{reason ? "[#{reason.code}] #{reason.message}" : 'unknown'}. The Amazon services for the
        affected region may be down. You can try the 'setup force' command. If the problem persists, report the issue.)
    end

    def retryable?
      @retryable
    end
  end

  # Data center issues
  class DataCenterAccessFailure < DiagnosticAwareException
    include TemporaryFailure

    attr_reader :agent_machine, :user_name, :ssh_identity

    # @param [String] user_name  ssh user name
    # @param [String] agent_machines comma separated ip addresses of machines
    # @param [String] ssh_identity ssh ssh identity
    def initialize(user_name, agent_machines, ssh_identity)
      super()

      @agent_machine = agent_machines
      @user_name = user_name
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
      super()

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
      super()

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
      super(region, reason)

      @region = region
      @reason = reason
      @retryable = true
    end

    def diagnostics
      %(Hailstorm cannot install JRE from the configured installer on region #{@region}: #{@reason})
    end
  end

  # JMeter installation issues
  class JMeterInstallationException < JavaInstallationException

    def diagnostics
      %(Hailstorm cannot install JMeter from the configured installer on region #{@region}: #{@reason})
    end
  end

  # Execution cycle exists, but it should not.
  class ExecutionCycleExistsException < DiagnosticAwareException

    def initialize(started_at)
      super()

      @started_at = started_at
    end

    def diagnostics
      "You have already started an execution cycle at #{@started_at}. Please stop or abort first."
    end
  end

  # Execution cycle does not exist, but it should.
  class ExecutionCycleNotExistsException < DiagnosticAwareException

    def diagnostics
      'Nothing to stop... no tests running'
    end
  end

  # JMeter was expected to be stopped, but it is still running.
  class JMeterRunningException < DiagnosticAwareException

    def diagnostics
      "Jmeter is still running! Run 'abort' if you really mean to stop."
    end
  end

  # Hailstorm SSH Exception
  class SSHException < Hailstorm::Exception; end
end
