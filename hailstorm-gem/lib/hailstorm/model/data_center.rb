# frozen_string_literal: true

require 'hailstorm'
require 'hailstorm/model'
require 'hailstorm/behavior/clusterable'
require 'hailstorm/behavior/loggable'
require 'hailstorm/behavior/sshable'
require 'hailstorm/support/ssh'

# DataCenter model - models the configuration for creating load agent
# on the Data Center.
class Hailstorm::Model::DataCenter < ActiveRecord::Base
  include Hailstorm::Behavior::Loggable
  include Hailstorm::Behavior::Clusterable
  include Hailstorm::Behavior::SSHable

  serialize :machines

  before_validation :set_defaults

  validates_presence_of :user_name, :machines, :ssh_identity

  validate :identity_file_ok, if: proc { |r| r.active? }

  # Seconds between successive Data Center status checks
  DOZE_TIME = 5

  # Creates a data center load agent with all required packages pre-installed and
  # starts requisite number of instances
  def setup(force: false)
    logger.debug { "#{self.class}##{__method__}" }

    self.save! if save_on_setup?
    return unless self.active? || force

    logger.info("Provisioning #{self.machines.size} #{self.class} machines...")
    provision_agents
  end

  def required_load_agent_count(jmeter_plan)
    jmeter_plan.num_threads > 1 ? self.machines.size : 1
  end

  # (see Hailstorm::Behavior::Clusterable#slug)
  def slug
    @slug ||= "#{self.class.name.demodulize.titlecase} #{self.title}".strip
  end

  ######################### PRIVATE METHODS ####################################
  private

  def identity_file_name
    File.basename(self.ssh_identity.gsub(/\.pem$/, '')).concat('.pem')
  end

  def set_defaults
    self.user_name = Defaults::SSH_USER if self.user_name.blank?
    self.title = Defaults::TITLE if self.title.blank?
  end

  def connection_ok?(load_agent)
    logger.debug { "#{self.class} agent##{load_agent.private_ip_address} checking access..." }
    Hailstorm::Support::SSH.ensure_connection(load_agent.private_ip_address, self.user_name, ssh_options)
  end

  # check if java is installed on agent or not
  # @return [Boolean] true if Java is installed
  def java_installed?(load_agent)
    logger.debug { "#{self.class}##{__method__}" }
    java_available = false
    Hailstorm::Support::SSH.start(load_agent.private_ip_address, self.user_name, ssh_options) do |ssh|
      output = ssh.exec!('command -v java')
      logger.debug { "output of java check #{output}" }
      java_available = true if output&.include?('java')
    end
    java_available
  end

  def java_version_ok?(load_agent)
    logger.debug { "#{self.class}##{__method__}" }
    java_version_ok = false
    Hailstorm::Support::SSH.start(load_agent.private_ip_address, self.user_name, ssh_options) do |ssh|
      output = ssh.exec!('java -version')
      logger.debug { output }
      java_version_ok = true if /version\s+"#{Defaults::JAVA_VERSION}\.[^"]+"/ =~ output
    end
    java_version_ok
  end

  def java_ok?(load_agent)
    logger.debug { "#{self.class} agent##{load_agent.private_ip_address} validating java installation..." }
    java_installed?(load_agent) && java_version_ok?(load_agent)
  end

  # check if jmeter is installed on agent
  # @return [Boolean] true if JMeter is installed
  def jmeter_installed?(load_agent)
    logger.debug { "#{self.class}##{__method__}" }
    jmeter_available = false
    Hailstorm::Support::SSH.start(load_agent.private_ip_address, self.user_name, ssh_options) do |ssh|
      output = nil
      ssh.exec!("ls -d #{jmeter_home}/bin/jmeter") do |_channel, stream, data|
        if stream == :stdout
          output = +'' if output.nil?
          output << data
        end
      end
      logger.debug { "output of jmeter check #{output}" }
      jmeter_available = true if output&.include?('jmeter')
    end
    jmeter_available
  end

  def jmeter_version_ok?(load_agent)
    logger.debug { "#{self.class}##{__method__}" }
    jmeter_version_ok = false
    Hailstorm::Support::SSH.start(load_agent.private_ip_address, self.user_name, ssh_options) do |ssh|
      output = ssh.exec!("#{jmeter_home}/bin/jmeter -n -v")
      logger.debug { "Output of JMeter version check #{output}" }
      if /Version\s#{self.project.jmeter_version}.*/m =~ output || /#{self.project.jmeter_version}\s*/m =~ output
        jmeter_version_ok = true
      end
    end
    jmeter_version_ok
  end

  def jmeter_ok?(load_agent)
    logger.debug { "#{self.class} agent##{load_agent.private_ip_address} validating jmeter installation..." }
    jmeter_installed?(load_agent) && jmeter_version_ok?(load_agent)
  end

  def save_on_setup?
    self.changed? || self.new_record?
  end

  def agents_to_add(query, _required_count, &_block)
    logger.debug { "#{self.class}##{__method__}" }
    current_machines = query.all.collect(&:private_ip_address)
    machines_added = [self.machines].flatten - current_machines
    machines_added.each do |machine|
      q = query.where(public_ip_address: machine, private_ip_address: machine, identifier: machine)
      yield q, machines_added.size
    end
    machines_added.size
  end

  def agents_to_remove(query, _required_count, &block)
    logger.debug { "#{self.class}##{__method__}" }
    current_machines = query.all.collect(&:private_ip_address)
    machines_removed = current_machines - [self.machines].flatten
    query.where(private_ip_address: machines_removed).each(&block)
  end

  def agent_before_save_on_create(load_agent)
    unless connection_ok?(load_agent)
      raise(Hailstorm::DataCenterAccessFailure.new(self.user_name,
                                                   load_agent.private_ip_address,
                                                   self.ssh_identity))
    end

    raise Hailstorm::DataCenterJavaFailure, Defaults::JAVA_VERSION unless java_ok?(load_agent)

    raise Hailstorm::DataCenterJMeterFailure, self.project.jmeter_version unless jmeter_ok?(load_agent)
  rescue Object => e
    if load_agent.persisted?
      load_agent.update_attribute(:active, false)
    else
      load_agent.active = false
    end
    raise e
  end

  # Data center default settings
  class Defaults
    SSH_USER            = 'ubuntu'
    TITLE               = 'Hailstorm'
    JAVA_VERSION        = '1.8'
    SSH_PORT            = 22
  end
end
