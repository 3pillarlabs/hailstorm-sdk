# Configuration for Hailstorm. This is exposed to the application to
# configure Hailstorm specific to the application needs.
# @author Sayantam Dey

require 'hailstorm/support'

class Hailstorm::Support::Configuration
  
  # Set the maximum number of threads spawned by a single load agent. If
  # unspecified, the default is 50. If the number of threads in the JMeter thread
  # group is higher than this value, multiple load agents will be spawned with
  # equal thread distribution.
  attr_accessor :max_threads_per_agent
  
  # Boolean value controls whether Jmeter is operated in master slave mode
  # or simultaneous mode, defaults to true
  attr_accessor :master_slave_mode

  # Comma separated string of intervals, example 1,5,10. The samples will be
  # broken in intervals of x < 1, 1 <= x < 5, 5 <= x < 10, x >= 10; where
  # x is the response time of the sample
  attr_accessor :samples_breakup_interval

  class JMeter
  
    # JMeter scripts to setup and execute. If left unset all files in app/jmx will be processed
    # for load generation. Multiple files can be specified using an array. File extensions
    # are not needed. If only one test plan is present, this configuration is not needed.
    attr_accessor :test_plans
    
    # Generic or test_plan specific properties. These will be used when constructing
    # and issuing a JMeter command
    def properties(options = {}, &block)
      
      @properties ||= {}
      @properties[:test_plan] = {} unless @properties.key?(:test_plan)
      @properties[:all] = {} unless @properties.key?(:all)
      
      if block_given?
        if options.key?(:test_plan)
          @properties[:test_plan][options[:test_plan]] = {}
          yield @properties[:test_plan][options[:test_plan]]
        else
          yield @properties[:all]
        end
      else
        if options.key?(:test_plan)
          @properties[:all].merge(@properties[:test_plan][options[:test_plan]] || {})
        else
          @properties[:all]
        end
      end
    end

  end

  # JMeter configuration
  def jmeter(&block)
    
    @jmeter ||= JMeter.new
    if block_given? 
      yield(@jmeter)
    else
      return @jmeter
    end
  end
  
  # Settings for one or more clusters, if block is passed, creates a config
  # object of the type passed and yields it. If block is not passed, returns the
  # clusters array.
  # @param [String] cluster_type
  # @return [Object] array or config object if block is given
  def clusters(cluster_type = nil, &block)
    
    @clusters ||= []
    if block_given?
      cluster_config_klass = "Hailstorm::Support::Configuration::#{cluster_type.to_s.camelize}"
                              .constantize()
      cluster_config = cluster_config_klass.new
      cluster_config.cluster_type = cluster_type.to_sym 
      yield cluster_config
      @clusters.push(cluster_config) 
    else
      @clusters
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
    
  end
  
  # Settings for Amazon Cloud. The class name should correspond to class name
  # in Hailstorm::Model namespace. Select this using the :amazon_cloud clusters
  # parameter.
  class AmazonCloud < ClusterBase
    # Amazon EC2 access key
    attr_accessor :access_key
    
    # Amazon EC2 secret key
    attr_accessor :secret_key
  
    # Name of ssh_identity file. The file should be present in application db directory.
    attr_accessor :ssh_identity
    
    # Amazon EC2 region for creating the AMI
    attr_accessor :region
    
    # Amazon EC2 zone ID specific to region used
    attr_accessor :zone
    
    # Amazon EC2 security groups. Separate multiple groups with comma
    attr_accessor :security_group
    
    # Agent AMI, if there already exists an AMI in same region
    attr_accessor :agent_ami
    
  end

  # Settings for one more monitors. Multiple monitors of different types can
  # be setup by repeating the monitors block. Monitor settings can be overridden
  # at the host level.
  # @param [Symbol] monitor_type the monitor type to use, needed if block_given.
  # @return [Object] array of monitors if no block_given else yields a
  #                  Hailstorm::Support::Configuration::TargetHost instance for setup
  def monitors(monitor_type = nil, &block)
    
    @monitors ||= [] unless self.frozen?
    if block_given?
      monitor = TargetHost.new()
      monitor.monitor_type = monitor_type
      def monitor.groups(role = nil, &block)
        @groups ||= []
        if block_given?
          group = TargetGroup.new()
          group.role = role
          yield group
          @groups.push(group)
        else
          @groups
        end
      end
      yield monitor
      @monitors.push(monitor)
    else
      return (@monitors || [])
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
    def hosts(*args, &block)

      @hosts ||= []
      if block_given?
        host = TargetHost.new()
        yield host
        @hosts.push(host)
      else
        if args.size == 0
          @hosts
        else
          args.each do |e|
            host = TargetHost.new()
            host.host_name = e
            @hosts.push(host)
          end
        end
      end 
    end
    
  end
  
  # Iterates through the monitors and returns the host definitions
  # @return [Array] of Hash, with attributes mapped to Hailstorm::Model::TargetHost
  def target_hosts()

    host_defs = []
    monitors.each do |monitor|
      next if monitor.active == false
      monitor.groups.each do |group|
        group.hosts.each do |host|
          next if host.active == false
          hdef = host.instance_values.symbolize_keys
          hdef[:type] = monitor.monitor_type
          hdef[:role_name] = group.role
          [:executable_path, :ssh_identity, :user_name, 
            :sampling_interval, :active].each do |sym|
            
            # take values from monitor unless the hdef contains the key
            hdef[sym] = monitor.send(sym) unless hdef.key?(sym)
          end
          hdef[:active] = true if hdef[:active].nil?
          host_defs.push(hdef)
        end
      end
    end
    
    return host_defs
  end
  
  # Computes the SHA2 hash of the environment file and contents/structure of JMeter
  # directory.
  # @return [String]
  def serial_version()

    digest = Digest::SHA2.new()

    Dir[File.join(Hailstorm.root, Hailstorm.app_dir, '**', '*.jmx')].sort.each do |file|
      digest.update(file)
    end

    File.open(Hailstorm.environment_file_path, 'r') do |ef|
      ef.each_line do |line|
        digest.update(line)
      end
    end

    digest.hexdigest()
  end
  alias :compute_serial_version :serial_version


end