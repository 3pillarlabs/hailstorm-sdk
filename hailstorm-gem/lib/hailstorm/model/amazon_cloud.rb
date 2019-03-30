require 'aws'

require 'hailstorm'
require 'hailstorm/model'
require 'hailstorm/behavior/loggable'
require 'hailstorm/behavior/clusterable'
require 'hailstorm/behavior/provisionable'
require 'hailstorm/behavior/sshable'
require 'hailstorm/support/ssh'
require 'hailstorm/support/amazon_account_cleaner'
require 'hailstorm/support/java_installer'
require 'hailstorm/support/jmeter_installer'
require 'hailstorm/support/waiter'

# Represents state and behavior for Amazon Web Services (AWS) cluster
# @author Sayantam Dey
class Hailstorm::Model::AmazonCloud < ActiveRecord::Base
  include Hailstorm::Behavior::Loggable
  include Hailstorm::Behavior::Clusterable
  include Hailstorm::Behavior::Provisionable
  include Hailstorm::Behavior::SSHable

  before_validation :set_defaults

  validates_presence_of :access_key, :secret_key, :region

  validates_presence_of :agent_ami, if: ->(r) { r.active? && r.ssh_port && r.ssh_port != Defaults::SSH_PORT }

  validate :identity_file_exists, if: proc { |r| r.active? }

  before_save :set_availability_zone, if: proc { |r| r.active? }

  before_save :create_security_group, if: proc { |r| r.active? }

  before_save :create_agent_ami, if: proc { |r| r.active? && r.agent_ami.nil? }

  after_destroy :cleanup

  # Creates an load agent AMI with all required packages pre-installed and
  # starts requisite number of instances
  def setup(force = false)
    logger.debug { "#{self.class}##{__method__}" }
    self.save! if self.changed? || self.new_record?
    return unless self.active? || force

    provision_agents
    secure_identity_file
  end

  # Delete SSH key-pair and identity once all load agents have been terminated
  # (see Hailstorm::Behavior::Clusterable#cleanup)
  def cleanup
    logger.debug { "#{self.class}##{__method__}" }
    return unless self.active? && self.autogenerated_ssh_key? && self.load_agents(true).empty?

    key_pair = ec2.key_pairs[self.ssh_identity]
    return unless key_pair.exists?

    key_pair.delete
    FileUtils.safe_unlink(identity_file_path)
  end

  # (see Hailstorm::Behavior::Clusterable#slug)
  def slug
    @slug ||= "#{self.class.name.demodulize.titlecase}, region: #{self.region}"
  end

  # (see Hailstorm::Behavior::Clusterable#public_properties)
  def public_properties
    columns = [:region]
    self.attributes.symbolize_keys.slice(*columns)
  end

  # Purges the Amazon accounts used of Hailstorm related artifacts
  def self.purge(cleaner = nil)
    logger.debug { "#{self}.#{__method__}" }
    self.group(:access_key, :secret_key)
        .select('access_key, secret_key')
        .each do |item|

      logger.debug { item }
      cleaner ||= Hailstorm::Support::AmazonAccountCleaner.new(access_key_id: item.access_key,
                                                               secret_access_key: item.secret_key)
      regions = []
      self.where(access_key: item.access_key, secret_key: item.secret_key, active: true).each do |record|
        record.update_column(:agent_ami, nil)
        regions.push(record.region)
      end
      cleaner.cleanup(false, regions)
    end
  end

  def self.round_off_max_threads_per_agent(computed)
    pivot = if computed <= 10
              5
            else
              computed <= 50 ? 10 : 50
            end
    (computed.to_f / pivot).round * pivot
  end

  # Helper methods for load agents
  module AgentHelper

    # start the agent and update agent ip_address and identifier
    def start_agent(load_agent)
      return if load_agent.running?

      agent_ec2_instance = ec2.instances[load_agent.identifier] unless load_agent.identifier.nil?
      if agent_ec2_instance
        restart_agent(agent_ec2_instance)
      else
        agent_ec2_instance = create_agent
        agent_ec2_instance.tag(
          'Name',
          value: "#{self.project.project_code}-#{load_agent.class.name.underscore}-#{load_agent.id}"
        )
      end
      # update attributes
      load_agent.identifier = agent_ec2_instance.instance_id
      load_agent.public_ip_address = agent_ec2_instance.public_ip_address
      load_agent.private_ip_address = agent_ec2_instance.private_ip_address
    end

    # stop the load agent
    def stop_agent(load_agent)
      if load_agent.identifier
        agent_ec2_instance = ec2.instances[load_agent.identifier]
        if agent_ec2_instance.status == :running
          logger.info("Stopping agent##{load_agent.identifier}...")
          agent_ec2_instance.stop
          wait_for("#{agent_ec2_instance.id} to stop",
                   err_attrs: { region: self.region }) { agent_ec2_instance.status.eql?(:stopped) }
        end
      else
        logger.warn('Could not stop agent as identifier is not available')
      end
    end

    # Start load agents if not started
    # (see Hailstorm::Behavior::Clusterable::LoadAgentHelper#before_generate_load)
    def before_generate_load
      logger.debug { "#{self.class}##{__method__}" }
      self.load_agents.where(active: true).each do |agent|
        unless agent.running?
          start_agent(agent)
          agent.save!
        end
      end
    end

    # Process the suspend option. Must be specified as {:suspend => true}
    # @param [Hash] options
    # (see Hailstorm::Behavior::Clusterable::LoadAgentHelper#after_stop_load_generation)
    def after_stop_load_generation(options = nil)
      logger.debug { "#{self.class}##{__method__}" }
      suspend = (options.nil? ? false : options[:suspend])
      return unless suspend

      self.load_agents.where(active: true).each do |agent|
        next unless agent.running?

        stop_agent(agent)
        agent.public_ip_address = nil
        agent.save!
      end
    end

    # Terminate load agent
    # (see Hailstorm::Behavior::Provisionable#before_destroy_load_agent)
    def before_destroy_load_agent(load_agent)
      agent_ec2_instance = ec2.instances[load_agent.identifier]
      if agent_ec2_instance.exists?
        logger.info("Terminating agent##{load_agent.identifier}...")
        agent_ec2_instance.terminate
        logger.debug { "Waiting for #{agent_ec2_instance.id} to terminate..." }
        wait_for("#{agent_ec2_instance.id} on #{self.region} region to terminate") do
          agent_ec2_instance.status.eql?(:terminated)
        end
      else
        logger.warn("Agent ##{load_agent.identifier} does not exist on EC2")
      end
    end

    def required_load_agent_count(jmeter_plan)
      if self.respond_to?(:max_threads_per_agent) && jmeter_plan.num_threads > self.max_threads_per_agent
        (jmeter_plan.num_threads.to_f / self.max_threads_per_agent).ceil
      else
        1
      end
    end

    def restart_agent(instance)
      if instance.status == :stopped
        logger.info("Restarting agent##{instance.id}...")
        instance.start
      end
      wait_for("#{instance.id} to restart", err_attrs: { region: self.region }) { instance.status.eql?(:running) }
    end

    def create_agent
      logger.info("Starting new agent on #{self.region}...")
      security_group_ids = self.security_group.split(/\s*,\s*/)
                               .map { |x| find_security_group(x) }
                               .map(&:id)
      create_ec2_instance(new_ec2_instance_attrs(self.agent_ami, security_group_ids))
    end
  end

  include AgentHelper

  ######################### PRIVATE METHODS ####################################
  private

  def set_defaults
    self.security_group = Defaults::SECURITY_GROUP if self.security_group.blank?
    self.user_name ||= Defaults::SSH_USER
    self.instance_type ||= Defaults::INSTANCE_TYPE
    self.max_threads_per_agent ||= default_max_threads_per_agent
    self.region ||= Defaults::EC2_REGION

    return if self.ssh_identity

    self.ssh_identity = [Defaults::SSH_IDENTITY, Hailstorm.app_name].join('_')
    self.autogenerated_ssh_key = true
  end

  def ec2(refresh = false)
    @ec2 = nil if refresh
    @ec2 ||= AWS::EC2.new(aws_config).regions[self.region]
  end

  def vpc
    @vpc ||= ec2.subnets[self.vpc_subnet_id].vpc if self.vpc_subnet_id
  end

  def aws_config
    @aws_config ||= {
      access_key_id: self.access_key,
      secret_access_key: self.secret_key,
      max_retries: 3,
      logger: logger
    }
  end

  # Sets the first available zone based on configured region
  # only if the project is configured in master slave mode
  def set_availability_zone
    logger.debug { "#{self.class}##{__method__}" }
    return unless self.zone.blank? && self.project.master_slave_mode?

    ec2.availability_zones.each do |z|
      if z.state == :available
        self.zone = z.name
        break
      end
    end
  end

  def default_max_threads_per_agent
    iclass, itype = self.instance_type.split(/\./).collect(&:to_sym)
    iclass ||= :m3
    itype ||= :medium
    iclass_factor = Defaults::INSTANCE_CLASS_SCALE_FACTOR[iclass] || 1
    itype_factor = Defaults::INSTANCE_TYPE_STEP.call(Defaults::KNOWN_INSTANCE_TYPES.index(itype).to_i + 1)
    self.class.round_off_max_threads_per_agent(iclass_factor * itype_factor * Defaults::MIN_THREADS_ONE_AGENT)
  end

  # Helper methods for SSH identity
  module IdentityHelper
    def identity_file_exists
      if not File.exist?(identity_file_path)
        key_pair = ec2.key_pairs[self.ssh_identity]
        if key_pair.exists?
          # can't get private_key of key_pair which has been created externally,
          # user needs to place the file manually
          errors.add(:ssh_identity, "not found at #{identity_file_path}")
        else
          create_key_pair
        end
      else
        errors.add(:ssh_identity, "at #{identity_file_path} must be a regular file") unless identity_file_ok?
      end
    end

    def create_key_pair
      logger.debug { "Creating #{self.ssh_identity} key_pair..." }
      key_pair = ec2.key_pairs.create(self.ssh_identity)
      File.open(identity_file_path, 'w') do |file|
        file.print(key_pair.private_key)
      end
    end

    def identity_file_name
      [self.ssh_identity.gsub(/\.pem/, ''), self.region].join('_').concat('.pem')
    end
  end

  # Helper methods for Security Groups
  module SecurityGroupHelper

    def create_security_group
      logger.debug { "#{self.class}##{__method__}" }
      security_group = find_security_group
      unless security_group
        logger.info("Creating #{self.security_group} security group on #{self.region}...")
        security_group = security_group_collection.create(self.security_group,
                                                          description: Defaults::SECURITY_GROUP_DESC, vpc: vpc)
        security_group.authorize_ingress(:tcp, (self.ssh_port || Defaults::SSH_PORT)) # allow SSH from anywhere
        # allow incoming TCP & UDP to any port within the group
        %i[tcp udp].each { |proto| security_group.authorize_ingress(proto, 0..65_535, group_id: security_group.id) }
        security_group.allow_ping # allow ICMP from anywhere
      end
      security_group
    end

    def find_security_group(group_name = nil)
      security_group_collection.filter('group-name', group_name || self.security_group).first
    end

    def security_group_collection
      @security_group_collection ||= (vpc || ec2).security_groups
    end
  end

  # Helper methods for EC2 instances
  module InstanceHelper

    # Builds the Hash attributes for creating a new EC2 instance.
    # @param [String] ami_id
    # @param [Array] security_group_ids
    # @return [Hash]
    def new_ec2_instance_attrs(ami_id, security_group_ids)
      attrs = { image_id: ami_id, key_name: self.ssh_identity, security_group_ids: security_group_ids,
                instance_type: self.instance_type, subnet: self.vpc_subnet_id }
      attrs[:availability_zone] = self.zone if self.zone
      attrs[:associate_public_ip_address] = true if self.vpc_subnet_id
      attrs
    end

    def perform_instance_checks(instance)
      logger.info { "Instance at #{self.region} running, waiting for system checks and ensuring SSH access..." }
      wait_for("#{instance.id} to start and successful system checks",
               timeout_sec: 600,
               sleep_duration: 10, err_attrs: { region: self.region }) { ec2_instance_ready?(instance) }
      ensure_ssh_connectivity(instance)
    rescue Exception => ex
      logger.warn("Failed to create new instance: #{ex.message}")
      raise(ex)
    end

    def ensure_ssh_connectivity(instance)
      return if Hailstorm::Support::SSH.ensure_connection(instance.public_ip_address, self.user_name, ssh_options)

      raise(Hailstorm::Exception, "Failed to connect to #{instance.id}")
    end

    # Predicate that returns true once the EC2 instance is ready.
    # @param [AWS::EC2::Instance] instance
    def ec2_instance_ready?(instance)
      instance.exists?.tap { |x| logger.debug { "instance.exists?: #{x}" } } &&
        instance.status.eql?(:running).tap { |x| logger.debug { "instance.status: #{x}" } } &&
        systems_ok(instance).tap { |x| logger.debug { "systems_ok: #{x}" } }
    end

    def systems_ok(ec2_instance)
      reachability_pass = ->(f) { f[:name] == 'reachability' && f[:status] == 'passed' }
      describe_instance_status(ec2_instance).reduce(true) do |state, e|
        system_reachable = e[:system_status][:details].select { |f| reachability_pass.call(f) }.empty?
        instance_reachable = e[:instance_status][:details].select { |f| reachability_pass.call(f) }.empty?
        state && !system_reachable && !instance_reachable
      end
    end

    def describe_instance_status(ec2_instance)
      ec2.client.describe_instance_status(instance_ids: [ec2_instance.id])[:instance_status_set]
    end

    def terminate_instance(instance)
      logger.debug { instance.inspect }
      instance.terminate
      logger.debug { "status: #{instance.status}" }
      wait_for("Instance #{instance.id} to terminate",
               err_attrs: { region: self.region }) { instance.status.eql?(:terminated) }
    end

    # Creates a new EC2 instance and returns the instance once it passes all checks.
    # @param [Hash] attrs EC2 instance attributes
    # @return [AWS::EC2::Instance]
    def create_ec2_instance(attrs)
      instance = ec2.instances.create(attrs)
      perform_instance_checks(instance)
      instance
    end
  end

  # Helper methods for installers in AMIs
  module InstallerHelper

    # install JMeter to self.user_home
    def install_jmeter(ssh)
      logger.info { "Installing JMeter for #{self.region} AMI..." }
      installer = Hailstorm::Support::JmeterInstaller.create
                                                     .with(:download_url, self.project.custom_jmeter_installer_url)
                                                     .with(:user_home, self.user_home)
                                                     .with(:jmeter_version, self.project.jmeter_version)
      installer.install do |instr|
        ssh.exec!(instr)
      end
    end

    # install JAVA
    def install_java(ssh)
      logger.info { "Installing Java for #{self.region} AMI..." }
      output = ''
      Hailstorm::Support::JavaInstaller.create.install do |instr|
        on_data = lambda do |data|
          output << data
          logger.debug { data }
        end
        instr_success = ssh_channel_exec_instr(ssh, instr, on_data)
        raise(Hailstorm::JavaInstallationException.new(self.region, output)) unless instr_success
      end
      output
    end

    # Executes the instruction on an SSH channel
    # @param ssh [Net::SSH::Connection::Session] open ssh session
    # @param instr [String] instruction to execute
    # @param on_data [Proc] handler for data on stdout and stderr
    # @return [Boolean] true if the instruction succeeded, false otherwise
    def ssh_channel_exec_instr(ssh, instr, on_data)
      instr_success = false
      channel = ssh.open_channel do |chnl|
        chnl.exec(instr) do |ch, success|
          instr_success = success
          ch.on_data { |_c, data| on_data.call(data) }
          ch.on_extended_data { |_c, _t, data| on_data.call(data) }
        end
      end
      channel.wait
      instr_success
    end
  end

  # Helper methods for creating agent AMI
  module AmiHelper

    # creates the agent ami
    def create_agent_ami
      return unless ami_creation_needed?

      # AMI does not exist
      logger.info("Creating agent AMI for #{self.region}...")
      clean_instance = ec2.instances.create(new_ec2_instance_attrs(base_ami, [find_security_group.id]))
      begin
        perform_instance_checks(clean_instance)
        build_ami(clean_instance)
      rescue Exception => ex
        logger.error("Failed to create instance on #{self.region}: #{ex.message}, terminating temporary instance...")
        raise(ex)
      ensure
        terminate_instance(clean_instance) if clean_instance
      end
    end

    # @return [Boolean] true if agent AMI should be created
    def ami_creation_needed?
      self.active? && self.agent_ami.nil? && check_for_existing_ami.nil?
    end

    # Check if this region already has the Hailstorm AMI and return the identifier.
    # @return [String] AMI id
    def check_for_existing_ami
      rexp = Regexp.compile(ami_id)
      logger.info("Searching available AMI on #{self.region}...")
      ex_ami = ec2.images.with_owner(:self).find { |e| e.state == :available && rexp.match(e.name) }
      if ex_ami
        logger.info("Using AMI #{self.agent_ami} for #{self.region}...")
        self.agent_ami = ex_ami.id
      end
      ex_ami
    end

    # Build the AMI from a running instance
    def build_ami(instance)
      provision(instance)
      logger.info { "Finalizing changes for #{self.region} AMI..." }
      self.agent_ami = register_hailstorm_ami(instance)
      logger.info { "New AMI##{self.agent_ami} on #{self.region} created successfully, cleaning up..." }
    end

    # Install everything
    def provision(instance)
      Hailstorm::Support::SSH.start(instance.public_ip_address, self.user_name, ssh_options) do |ssh|
        install_java(ssh)
        install_jmeter(ssh)
      end
    end

    # Create and register the AMI
    # @param [AWS::EC2::Instance] instance instance that will be registered as an AMI
    def register_hailstorm_ami(instance)
      new_ami = ec2.images.create(
        name: ami_id,
        instance_id: instance.instance_id,
        description: 'AMI for distributed performance testing with Hailstorm'
      )
      wait_for("Hailstorm AMI #{ami_id} on #{self.region} to be created") { new_ami.state == :available }
      logger.debug { "new_ami.state: #{new_ami.state}" }
      raise(Hailstorm::AmiCreationFailure.new(self.region, new_ami.state_reason)) unless new_ami.state == :available

      new_ami.id
    end

    # Architecture as per instance_type - everything is 64-bit.
    def arch(internal = false)
      internal ? '64-bit' : 'x86_64'
    end

    # The AMI ID to search for and create
    def ami_id
      [Defaults::AMI_ID,
       "j#{self.project.jmeter_version}"].tap do |lst|
        self.project.custom_jmeter_installer_url ? lst.push(self.project.project_code) : lst
      end.push(arch).join('-')
    end

    # Base AMI to use to create Hailstorm AMI based on the region and instance_type
    # @return [String] Base AMI ID
    def base_ami
      region_base_ami_map[self.region][arch(true)]
    end

    # Static map of regions, architectures and AMI ID of latest stable Ubuntu LTS AMIs
    # On changes to this map, be sure to execute ``rspec -t integration``.
    ARCH_64 = '64-bit'.freeze

    def region_base_ami_map
      @region_base_ami_map ||= [
        { region: 'us-east-1',      ami: 'ami-d05e75b8' }, # US East (Virginia)
        { region: 'us-east-2',      ami: 'ami-8b92b4ee' }, # US East (Ohio)
        { region: 'us-west-1',      ami: 'ami-df6a8b9b' }, # US West (N. California)
        { region: 'us-west-2', 	    ami: 'ami-5189a661' }, # US West (Oregon)
        { region: 'ca-central-1',   ami: 'ami-b3d965d7' }, # Canada (Central)
        { region: 'eu-west-1',      ami: 'ami-47a23a30' }, # EU (Ireland)
        { region: 'eu-central-1',   ami: 'ami-accff2b1' }, # EU (Frankfurt)
        { region: 'eu-west-2',      ami: 'ami-cc7066a8' }, # EU (London)
        { region: 'ap-northeast-1', ami: 'ami-785c491f' }, # Asia Pacific (Tokyo)
        { region: 'ap-southeast-1', ami: 'ami-2378f540' }, # Asia Pacific (Singapore)
        { region: 'ap-southeast-2', ami: 'ami-e94e5e8a' }, # Asia Pacific (Sydney)
        { region: 'ap-northeast-2', ami: 'ami-94d20dfa' }, # Asia Pacific (Seoul)
        { region: 'ap-south-1',     ami: 'ami-49e59a26' }, # Asia Pacific (Mumbai)
        { region: 'sa-east-1',      ami: 'ami-34afc458' }  # South America (Sao Paulo)
      ].reduce({}) { |s, e| s.merge(e[:region] => { ARCH_64 => e[:ami] }) }
    end
  end

  include Hailstorm::Support::Waiter
  include IdentityHelper
  include SecurityGroupHelper
  include InstanceHelper
  include InstallerHelper
  include AmiHelper

  # EC2 default settings
  class Defaults
    AMI_ID              = '3pg-hailstorm'.freeze
    SECURITY_GROUP      = 'Hailstorm'.freeze
    SECURITY_GROUP_DESC = 'Allows SSH traffic from anywhere and all internal TCP, UDP and ICMP traffic'.freeze
    BUCKET_NAME         = 'brickred-perftest'.freeze
    SSH_USER            = 'ubuntu'.freeze
    SSH_IDENTITY        = 'hailstorm'.freeze
    INSTANCE_TYPE       = 'm3.medium'.freeze
    INSTANCE_CLASS_SCALE_FACTOR = {
      t2: 2, m4: 4, m3: 4, c4: 8, c3: 8, r4: 10, r3: 10, d2: 10, i2: 10, i3: 10, x1: 20
    }.freeze
    INSTANCE_TYPE_SCALE_FACTOR = 2
    KNOWN_INSTANCE_TYPES = [:nano, :micro, :small, :medium, :large, :xlarge, '2xlarge'.to_sym, '4xlarge'.to_sym,
                            '10xlarge'.to_sym, '16xlarge'.to_sym, '32xlarge'.to_sym].freeze
    INSTANCE_TYPE_STEP = lambda { |n|
      a = 1
      b = 1
      s = 1
      (n - 1).times do
        s = a + b
        a = b
        b = s
      end
      s
    }
    MIN_THREADS_ONE_AGENT = 2
    SSH_PORT = Hailstorm::Behavior::SSHable::Defaults::SSH_PORT
    EC2_REGION = 'us-east-1'.freeze
  end
end
