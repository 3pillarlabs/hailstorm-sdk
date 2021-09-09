# frozen_string_literal: true

require 'hailstorm/support'

# Configuration for Hailstorm. This is exposed to the application to
# configure Hailstorm specific to the application needs.
# @author Sayantam Dey
class Hailstorm::Support::Configuration
  # Boolean value controls whether Jmeter is operated in master slave mode
  # or simultaneous mode, defaults to true
  attr_accessor :master_slave_mode

  # Comma separated string of intervals, example 1,5,10. The samples will be
  # broken in intervals of x < 1, 1 <= x < 5, 5 <= x < 10, x >= 10; where
  # x is the response time of the sample
  attr_accessor :samples_breakup_interval

  # JMeter configuration
  class JMeter
    # JMeter version used in project. The default is 2.4. Specify only the version
    # component, example: 2.5 or 2.6
    attr_accessor :version

    # JMeter scripts to setup and execute. If left unset all files in app/jmx will be processed
    # for load generation. Multiple files can be specified using an array. File extensions
    # are not needed. If only one test plan is present, this configuration is not needed.
    # @param [Array<String>] test_plans
    attr_accessor :test_plans

    # Relative file paths from application directory for data files used by JMeter plans.
    # This is an optional property.
    attr_accessor :data_files

    # URL for a custom JMeter installer. The installer file must be a tar gzip and match:
    # /^[a-zA-Z][a-zA-Z0-9_\-\.]*\.ta?r?\.?gz/
    attr_accessor :custom_installer_url

    def initialize
      self.data_files = []
    end

    # Generic or test_plan specific properties. These will be used when constructing
    # and issuing a JMeter command
    def properties(options = {})
      @properties ||= {}
      @properties[:test_plan] = {} unless @properties.key?(:test_plan)
      @properties[:all] = {} unless @properties.key?(:all)

      if block_given?
        yield yield_properties(options)
      else
        properties_context(options)
      end
    end

    # @param [String] test_plan
    # @return [Array<String>]
    def add_test_plan(test_plan)
      @test_plans = [] if @test_plans.nil?
      @test_plans.push(File.strip_ext(test_plan))
      @test_plans
    end

    private

    def properties_context(options)
      if options.key?(:test_plan)
        test_plan_name = File.strip_ext(options[:test_plan])
        @properties[:all].merge(@properties[:test_plan][test_plan_name] || {})
      else
        @properties[:all]
      end
    end

    def yield_properties(options)
      if options.key?(:test_plan)
        test_plan_name = File.strip_ext(options[:test_plan])
        @properties[:test_plan][test_plan_name] = {}
        @properties[:test_plan][test_plan_name]
      else
        @properties[:all]
      end
    end
  end

  # JMeter configuration
  def jmeter
    @jmeter ||= JMeter.new unless self.frozen?
    if block_given?
      yield(@jmeter)
    else
      (@jmeter || JMeter.new)
    end
  end

  # Settings for one or more clusters, if block is passed, creates a config
  # object of the type passed and yields it. If block is not passed, returns the
  # clusters array.
  # @param [String] cluster_type
  # @return [Object] array or config object if block is given
  def clusters(cluster_type = nil)
    @clusters ||= [] unless self.frozen?
    if block_given?
      cluster_config_klass = "Hailstorm::Support::Configuration::#{cluster_type.to_s.camelize}"
                             .constantize
      cluster_config = cluster_config_klass.new
      cluster_config.cluster_type = cluster_type.to_sym
      yield cluster_config
      @clusters.push(cluster_config)
    else
      @clusters || []
    end
  end

  # Base class for all configuration classes
  class ClusterBase
    # Cluster Type - not to be set by end users
    attr_accessor :cluster_type #:nodoc:

    # SSH user-name
    attr_accessor :user_name

    # Set to true if this cluster should be considered for setup/load generation
    attr_accessor :active

    # Optional code name for cluster
    attr_accessor :cluster_code

    # Optional SSH port to specify non-standard SSH port
    attr_accessor :ssh_port

    def aws_required?
      false
    end
  end

  # Settings for Amazon Cloud. The class name should correspond to class name
  # in Hailstorm::Model namespace. Select this using the :amazon_cloud clusters
  # parameter.
  class AmazonCloud < ClusterBase
    # Amazon EC2 access key
    attr_accessor :access_key

    # Amazon EC2 secret key
    attr_accessor :secret_key

    # Name of ssh_identity file. The file should be present in application config directory.
    attr_accessor :ssh_identity

    # Amazon EC2 region for creating the AMI
    attr_accessor :region

    # Amazon EC2 zone ID specific to region used
    attr_accessor :zone

    # Amazon EC2 security groups. Separate multiple groups with comma
    attr_accessor :security_group

    # Agent AMI, if there already exists an AMI in same region
    attr_accessor :agent_ami

    # Instance type. Available instance types are -
    #   * m1.small' (default)
    #   * m1.large'
    #   * m1.xlarge'
    #   * c1.xlarge'
    #   * cc1.4xlarge'
    #   * cc2.8xlarge'
    #
    # m1.small is suitable for development and exploratory testing
    attr_accessor :instance_type

    # Set the maximum number of threads spawned by a single load agent.
    # If the number of threads in the JMeter thread group is higher than this
    # value, multiple load agents will be spawned with equal thread distribution.
    attr_accessor :max_threads_per_agent

    # Set the VPC Subnet ID to launch Hailstorm instance inside a VPC
    attr_accessor :vpc_subnet_id

    # Set the Base AMI when using an unsupported region
    attr_accessor :base_ami

    def aws_required?
      true
    end
  end

  # Settings for Data Center. The class name should correspond to class name
  # in Hailstorm::Model namespace. Select this using the :data_center clusters
  # parameter.
  class DataCenter < ClusterBase
    # Datacenter display identifier
    attr_accessor :title

    # Datacenter password
    attr_accessor :user_name

    # Datacenter access ssh key file
    attr_accessor :ssh_identity

    # Array of ip_addresses
    attr_accessor :machines
  end

  # Settings for one more monitors. Multiple monitors of different types can
  # be setup by repeating the monitors block. Monitor settings can be overridden
  # at the host level.
  # @param [Symbol] monitor_type the monitor type to use, needed if block_given.
  # @return [Object] array of monitors if no block_given else yields a
  #                  Hailstorm::Support::Configuration::TargetHost instance for setup
  def monitors(monitor_type = nil)
    @monitors ||= [] unless self.frozen?
    if block_given?
      monitor = TargetHost.new
      monitor.monitor_type = monitor_type
      yield monitor
      @monitors.push(monitor)
    else
      (@monitors || [])
    end
  end

  # Target configuration class. A target is a host where performance metrics
  # such as memory usage, CPU usage etc need to be collected.
  class TargetHost
    # IP address or host_name of target
    attr_accessor :host_name

    # Monitoring tool used, right now only :nmon is supported
    attr_accessor :monitor_type

    # Path to monitoring executable. If there is no executable, leave blank
    attr_accessor :executable_path

    # Name of SSH identity file, leave blank if SSH is not used
    attr_accessor :ssh_identity

    # User name to access the target
    attr_accessor :user_name

    # Interval (specified in seconds) between successive samplings, default is 5 seconds
    attr_accessor :sampling_interval

    # Set this to false to exclude a host from performance metric collection
    attr_accessor :active

    def groups(role = nil)
      @groups ||= []
      if block_given?
        group = TargetGroup.new
        group.role = role
        yield group
        @groups.push(group)
      else
        @groups
      end
    end
  end

  # Target groups essentially label different hosts as per purpose - examples
  # 'Web Servers', 'Databases', etc...
  class TargetGroup
    attr_accessor :role

    # Specify one or more hosts as arguments, where each argument is a host_name.
    # Hosts specified in such mannner will derive settings from the parent monitor.
    # Another way is to specify a block, which is yielded a Hailstorm::Configuration::TargetHost
    # instance, which can be used override specifc attributes at the host level.
    # @return [Array] of Hailstorm::Configuration::TargetHost instances
    def hosts(*args)
      @hosts ||= []
      if block_given?
        host = TargetHost.new
        yield host
        @hosts.push(host)
      elsif args.empty?
        @hosts
      else
        args.each do |e|
          host = TargetHost.new
          host.host_name = e
          @hosts.push(host)
        end
      end
    end
  end
end
