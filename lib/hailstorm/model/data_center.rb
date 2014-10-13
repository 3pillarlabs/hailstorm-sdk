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

  validates_presence_of :user_name, :machines, :ssh_identity

  after_destroy :cleanup

  # Seconds between successive Data Center status checks
  DOZE_TIME = 5

  # Creates a data center load agent with all required packages pre-installed and
  # starts requisite number of instances
  def setup(force = false)
    puts "Inside #{self.class}##{__method__}"
    logger.debug { "#{self.class}##{__method__}" }

    # check machine status
    # check master slave
    # create load agents

    #TODO check master slave
    self.provision_agents()
    status = true
    self.machines.each do |machine|
      #check machine status
      if machine_status?(machine)
        status &=true
      else
        status &= false
      end
    end
    if status
      if self.active?
        self.save!()
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
      # SSH is available a while later even though status may be running
      logger.info { "agent##{load_agent.public_ip_address} is running, ensuring SSH access..." }
      Hailstorm::Support::SSH.ensure_connection(load_agent.public_ip_address,
                                                self.user_name, ssh_options)
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
      unless agent.running?
        #start_agent(agent)
        agent.save!
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



  # (see Hailstorm::Behavior::Clusterable#slug)
  def slug()
    @slug ||= "#{self.class.name.demodulize.titlecase}, region: #{self.title}"
  end


  ################## NEED TO MODIFY ACCORDING TO SCHEMA
  def self.purge()
    self.group(:user_name, :ssh_identity)
    .select("user_name, ssh_identity")
    .each do |item|
    # Remove any JMeter log that might be present there

    end
  end

  # Launch new instances or bring down instances based on number of instances needed
  def provision_agents()
    puts "Inside #{self.class}##{__method__}"
    logger.debug { "#{self.class}##{__method__}" }
    self.project.jmeter_plans.where(:active => true).each do |jmeter_plan|
      common_attributes = {
          :jmeter_plan_id => jmeter_plan.id,
          :active => true
      }
      required_count = required_load_agent_count()

      if self.project.master_slave_mode?
        query = self.master_agents
        .where(:jmeter_plan_id => jmeter_plan.id)

        # abort if more than 1 master agent is present
        if query.all.count > 1
          raise(Hailstorm::MasterSlaveSwitchOnConflict)
        end

        # one master is necessary
        query.first_or_create!()
        .tap {|agent| agent.update_column(:active, true)}

        if required_count > 1
          create_or_enable(common_attributes, required_count, :slave_agents)
        end

      else # not operating in master-slave mode
        # abort if slave agents are present
        slave_agents_count = self.slave_agents
        .where(:jmeter_plan_id => jmeter_plan.id)
        .all.count()
        if slave_agents_count > 0
          raise(Hailstorm::MasterSlaveSwitchOffConflict)
        end

        begin
          create_or_enable(common_attributes, required_count, :master_agents)
        rescue Exception => e
          logger.error(e.message)
          logger.debug { "\n".concat(e.backtrace().join("\n")) }
          raise(Hailstorm::AgentCreationFailure)
        end
      end
    end
  end

  ######################### PRIVATE METHODS ####################################
  private
  #################### WE ARE NOY USING KEY FOR NOW SO WE DON'T NEED THESE FUNCTIONS

  # Creates master/slave agents based on the relation
  def create_or_enable(attributes, required_count, relation)

    # count of active agents
    active_count = self.send(relation).where(attributes).all().count()

    activate_count = required_count - active_count

    activate_count.times do # block wont execute if activate_count <= 0

      # is there an inactive agent? if yes, activate it, or, create new
      agent = self.send(relation)
      .where(attributes.merge(:active => false))
      .first_or_initialize(:active => true)
      if agent.new_record?
        if activate_count > 1
          Hailstorm::Support::Thread.start(agent) do |agent_instance|
            #start_agent(agent_instance)
            agent_instance.save!
          end
        else
          #start_agent(agent)
          agent.save!
        end
      else
        agent.update_column(:active, true)
      end
    end
    Hailstorm::Support::Thread.join() if activate_count > 1# wait for agents to be created

    if activate_count < 0
      self.send(relation)
      .where(attributes)
      .limit(activate_count.abs).each do |agent|

        agent.update_column(:active, false)
      end
    end
  end

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
    #check if Hailstorm can SSH to specified machine
    #logger.info("Checking SSH connectivity status #{ip_address}")

    status = Hailstorm::Support::SSH.ensure_connection(ip_address,
                                                               self.user_name, ssh_options)
    return status
  end

  def machines_status?
    status = true
    self.machines.each do |machine|
      status &=machine_status?(machine)
    end
    return status
  end

  # check if
  # @return
  def java_installed?(load_agent)
    logger.debug { "#{self.class}##{__method__}" }
    java_available = false
    Hailstorm::Support::SSH.start(load_agent.private_ip_address,self.user_name, ssh_options) do |ssh|
      output = ssh.exec!("command -pv java")
      logger.debugger ("output of java check #{output}")
      if not output.nil? and output.include? "java"
        java_available = true
      end
    end
    return java_available
  end

  def jmeter_installed?(load_agent)
    jmeter_available = false
    Hailstorm::Support::SSH.start(load_agent.private_ip_address,self.user_name, ssh_options) do |ssh|
      output = ssh.exec!("command -pv jmeter")
      logger.debugger ("output of java check #{output}")
      if not output.nil? and output.include? "jmeter"
        jmeter_available = true
      end
    end
    return jmeter_available
  end

  def java_version()

  end

  def jmeter_version()

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
    MACHINES            = ['127.0.0.1', '127.0.0.1']
    TITLE               = 'Hailstorm'
  end
end