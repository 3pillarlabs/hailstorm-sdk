# DataCenter model - models the configuration for creating load agent
# on the Data Center.

require 'aws'
require 'hailstorm'
require 'hailstorm/model'
require 'hailstorm/behavior/clusterable'
require 'hailstorm/support/ssh'
require 'hailstorm/support/amazon_account_cleaner'

class Hailstorm::Model::DataCenter < ActiveRecord::Base
  include Hailstorm::Behavior::Clusterable

  before_validation :set_defaults
  serialize :machines

  validates_presence_of :user_name, :machines, :ssh_identity

  after_destroy :cleanup

  # Seconds between successive Data Center status checks
  DOZE_TIME = 5

  # Creates a data center load agent with all required packages pre-installed and
  # starts requisite number of instances
  def setup(force = false)
    logger.debug { "#{self.class}##{__method__}" }

    # check machines are connectable
    if machines_connectable?
      if self.active?
        self.save!()
        # check master slave
        # create load agents
        provision_agents()
      else
        self.update_column(:active, false) if self.persisted?
      end
    else
      raise(Hailstorm::DataCenterAccessFailure.new(self.user_name, self.machines, self.ssh_identity))
    end
  end

  # start the agent and update agent ip_address and identifier
  def start_agent(load_agent)
    logger.debug { "#{self.class}##{__method__}" }
    #verify everything is ok with machines
    verify_machines_status()
    if load_agent.private_ip_address.nil?
      ip = self.machines.shift()
      # update attributes
      load_agent.identifier = ip
      load_agent.public_ip_address = ip
      load_agent.private_ip_address = ip

      # SSH is available a while later even though status may be running
      puts "Ensuring SSH access to agent##{load_agent.private_ip_address} with user name #{self.user_name}..."
      sleep(10)
      logger.debug { "sleep over..."}
      Hailstorm::Support::SSH.ensure_connection(load_agent.private_ip_address,
                                                self.user_name, ssh_options)

    end
  end

  # stop the load agent
  def stop_agent(load_agent)
    logger.debug { "#{self.class}##{__method__}" }
    #See if we need log download
  end

  #@return [Hash] of SSH options
  #(see Hailstorm::Behavior::Clusterable#ssh_options)
  def ssh_options()
    @ssh_options ||= {:password => 'ubuntu' }
  end

  # Start load agents if not started
  # (see Hailstorm::Behavior::Clusterable#before_generate_load)
  def before_generate_load()
    logger.debug { "#{self.class}##{__method__}" }
    self.load_agents.where(:active => true).each do |agent|
      unless agent.private_ip_address.nil?
        start_agent(agent)
        agent.save!
      end
    end
  end

  # Process the suspend option. Must be specified as {:suspend => true}
  # @param [Hash] options
  # (see Hailstorm::Behavior::Clusterable#after_stop_load_generation)
  def after_stop_load_generation(options = nil)
    logger.debug { "#{self.class}##{__method__}" }
    suspend = (options.nil? ? false : options[:suspend])
    if suspend
      self.load_agents.where(:active => true).each do |agent|
        if agent.running?
          stop_agent(agent)
          agent.public_ip_address = nil
          agent.save!
        end
      end
    end
  end

  def required_load_agent_count()
    return self.machines.count()
  end

  # Terminate load agent
  # (see Hailstorm::Behavior::Clusterable#before_destroy_load_agent)
  def before_destroy_load_agent(load_agent)
    logger.debug { "#{self.class}##{__method__}" }
  end

  def cleanup()
    logger.debug { "#{self.class}##{__method__}" }
      if self.load_agents(true).empty?
        #connect to each machine and remove the test folder
        self.machines.each do |machine|
          puts machine
        end
      end
  end

  # (see Hailstorm::Behavior::Clusterable#slug)
  def slug()
    @slug ||= "#{self.class.name.demodulize.titlecase}, data center: #{self.title}"
  end


  ################## NEED TO MODIFY ACCORDING TO SCHEMA
  def self.purge()
    self.group(:user_name, :ssh_identity)
    .select("user_name, ssh_identity")
    .each do |item|
    # Remove any JMeter log that might be present there

    end
  end

  ######################### PRIVATE METHODS ####################################
  private
  #################### WE ARE NOY USING KEY FOR NOW SO WE DON'T NEED THESE FUNCTIONS

  def identity_file_exists?
    return File.exists?(identity_file_path)
  end
  def identity_file_path()
    @identity_file_path ||= File.join(Hailstorm.root, Hailstorm.db_dir, self.ssh_identity)
  end


  def set_defaults()
    self.user_name ||= Defaults::SSH_USER
    self.machines ||= Defaults::MACHINES
    self.title ||= Defaults::TITLE
    if self.ssh_identity.nil?
      self.ssh_identity = [Defaults::SSH_IDENTITY, Hailstorm.app_name].join('_')
    end
  end

  def machine_status?(ip_address)
    #TODO check if Hailstorm can SSH to specified machine, check Java and jMeter

    return Hailstorm::Support::SSH.ensure_connection(ip_address,
                                                       self.user_name, ssh_options)
  end

  def machines_connectable?
    status = true
    self.machines.each do |machine|
      status &= machine_status?(machine)
    end
    return status
  end

  def verify_machines_status()
    logger.debug { "#{self.class}##{__method__}" }
    logger.debug { "Verifying all machines are connectable" }
    raise(Hailstorm::DataCenterAccessFailure.new(
              self.user_name, self.machines, self.ssh_identity)
    ) if not machines_connectable?

    logger.debug { "Verifying if all machines have required Java Version" }
    raise(Hailstorm::DataCenterJavaFailure.new("1.6")) if not java_available?

    logger.debug { "Verifying if all machines have required JMeter Version" }
    #raise(Hailstorm::DataCenterJMeterFailure.new("2.7")) if not jmeter_available?
  end

  def java_available?
    status = true
    self.machines.each do |machine|
      status &= java_installed?(machine)
    end
    return status
  end

  def jmeter_available?
    status = true
    self.machines.each do |machine|
      status &= jmeter_installed?(machine)
    end
    return status
  end

  # check if java is installed on target machine
  # @return
  def java_installed?(ip_address)
    logger.debug { "#{self.class}##{__method__}" }
    java_available = false
    Hailstorm::Support::SSH.start(ip_address,self.user_name, ssh_options) do |ssh|
      output = ssh.exec!("command -v java")
      logger.debug ("output of java check #{output}")
      if not output.nil? and output.include? "java"
        java_available = true
      end
    end
    return java_available
  end

  def jmeter_installed?(ip_address)
    jmeter_available = false
    Hailstorm::Support::SSH.start(ip_address,self.user_name, ssh_options) do |ssh|
      output = ssh.exec!("command -v jmeter")
      logger.debug ("output of java check #{output}")
      if not output.nil? and output.include? "jmeter"
        jmeter_available = true
      end
    end
    return jmeter_available
  end

  def java_version_ok?(ip_address)
    logger.debug { "#{self.class}##{__method__}" }
    java_available = false
    Hailstorm::Support::SSH.start(ip_address,self.user_name, ssh_options) do |ssh|
      output = ssh.exec!("java -version")
      logger.debug ("output of java version check #{output}")
      #/java\sversion\s\"[1]\.[6-7]{1}\.[0-9].*\"/g
      if not output.nil? and output.include? "java"
        java_available = true
      end
    end
    return java_available
  end

  def jmeter_version_ok?

  end


  # @return [String] thead-safe name for the downloaded environment file
  def current_env_file_name()
    "environment-#{self.id}~"
  end

  # @return [String] thread-safe name for environment file to be written locally
  # for upload to agent.
  def new_env_file_name()
    "environment-#{self.id}"
  end

  # Waits for <tt>timeout_sec</tt> seconds for condition in <tt>block</tt>
  # to return true, else throws a Timeout::Error
  # @param [Integer] timeout_sec
  # @param [Proc] block
  # @raise [Timeout::Error] if block does not return true within timeout_sec
  def wait_until(timeout_sec = 300, &block)
    # make the timeout configurable by an environment variable
    timeout_sec = ENV['HAILSTORM_EC2_TIMEOUT'] || timeout_sec
    total_elapsed = 0
    while total_elapsed <= (timeout_sec * 1000)
      before_yield_time = Time.now.to_i
      result = yield
      if result
        break
      else
        sleep(DOZE_TIME)
        total_elapsed += (Time.now.to_i - before_yield_time)
      end
    end
  end

  def timeout_message(message, &block)
    begin
      yield
    rescue Timeout::Error
      raise(Hailstorm::Exception, "Timeout while waiting for #{message} on #{self.region}.")
    end
  end
  # Data center default settings
  class Defaults
    SSH_USER            = 'ubuntu'
    SSH_IDENTITY        = 'server.pem'
    MACHINES            = ['172.20.2.17', '172.20.2.18'] #Default machines for development
    TITLE               = 'Hailstorm'
  end
end