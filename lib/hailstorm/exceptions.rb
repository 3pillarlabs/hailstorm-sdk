module Hailstorm

  # Subclass or use this for exceptions in workflow
  class Exception < StandardError
  end

  class ThreadJoinException < Exception

    # @param [Array] exceptions
    def initialize(exceptions)
      @exceptions = exceptions
    end

    def message
      @message ||= @exceptions.nil? ? super.message : @exceptions.collect(&:message)
    end
  end

  class DiagnosticAwareException < Exception
    def message
      @message ||= diagnostics.gsub(/[ \t]{2,}/, ' ').freeze
    end
    def diagnostics
      ""
    end
  end

  class MasterSlaveSwitchOnConflict < DiagnosticAwareException
    def diagnostics
      %{You have switched ON master slave mode in the middle of a test
        execution. The current setup is no longer valid. Please 'terminate'
        current cycle first and 'setup' again.}
    end
  end

  class MasterSlaveSwitchOffConflict < DiagnosticAwareException
    def diagnostics
      %{You have switched OFF master slave mode in the middle of a test
        execution. The current setup is no longer valid. Please 'terminate'
        current cycle first and 'setup' again.}
    end
  end

  class AgentCreationFailure < DiagnosticAwareException
    def diagnostics
      %{One or more agents could not be prepared for load generation.
        This can happen due to issues in your cluster such as Amazon or
        your data-center or a misconfiguration. Try 'setup force'.}
    end
  end

  class JMeterVersionNotFound < DiagnosticAwareException
    
    attr_reader :jmeter_version, :bucket_name

    # @param [Object] jmeter_version
    # @param [String] bucket_name
    def initialize(jmeter_version, bucket_name)
      @jmeter_version = jmeter_version
      @bucket_name = bucket_name
    end

    def diagnostics
      %{The JMeter version '#{jmeter_version}' specified in
        [config/environment.rb] cannot be installed. If you would like to use
        a custom JMeter package, make sure the associated {VERSION}.tgz file is
        uploaded to Amazon S3 bucket '#{bucket_name}'. If you are unsure,
        remove the jmeter_version property.}
    end
  end

  class AmiCreationFailure < DiagnosticAwareException

    attr_reader :region, :reason

    # @param [String] region
    # @param [Object] reason AWS::EC2::Image#state_reason
    def initialize(region, reason)
      @region = region
      @reason = reason
    end

    def diagnostics
      %{AMI could not be created in AWS region '#{region}'. The failure reason
        from Amazon is: "[#{reason.code}] #{reason.message}". The Amazon services for the affected
        region may be down. You can try the 'setup force' command. If the
        problem perists, report the issue.}
    end
  end


end
