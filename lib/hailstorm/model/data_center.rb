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

  validates_presence_of :access_key, :secret_key, :region

  validate :identity_file_exists, :if => proc {|r| r.active?}

  validate :instance_type_supported, :if => proc {|r| r.active?}

  before_save :set_availability_zone, :if => proc {|r| r.active?}

  before_save :create_agent_ami, :if => proc {|r| r.active? and r.agent_ami.nil?}

  after_destroy :cleanup

  # Seconds between successive Data Center status checks
  DOZE_TIME = 5

  # Creates a data center load agent with all required packages pre-installed and
  # starts requisite number of instances
  def setup(force = false)
    logger.debug { "#{self.class}##{__method__}" }
    if self.active?
      self.agent_ami = nil if force
      self.save!()
      provision_agents()
      File.chmod(0400, identity_file_path())
    else
      self.update_column(:active, false) if self.persisted?
    end
  end

  # start the agent and update agent ip_address and identifier
  def start_agent(load_agent)
    logger.debug { load_agent.attributes.inspect }
    unless load_agent.running?
      agent_data_center_instance = nil
      unless load_agent.identifier.nil?
        agent_data_center_instance = data_center.instances[load_agent.identifier]
        if :stopped == agent_data_center_instance.status
          logger.info("Restarting agent##{load_agent.identifier}...")
          agent_data_center_instance.start()
          timeout_message("#{agent_data_center_instance.id} to restart") do
            wait_until { agent_data_center_instance.status.eql?(:running) }
          end
        end
      else
        logger.info("Starting new agent on #{self.region}...")
        agent_data_center_instance = ec2.instances.create(
            {:image_id => self.agent_ami,
             :key_name => self.ssh_identity,
             :security_groups => self.security_group.split(/\s*,\s*/),
             :instance_type => self.instance_type}.merge(
                self.zone.nil? ? {} : {:availability_zone => self.zone}
            )
        )
        timeout_message("#{agent_data_center_instance.id} to start") do
          wait_until { agent_data_center_instance.exists? && agent_data_center_instance.status.eql?(:running) }
        end
      end

      # update attributes
      load_agent.identifier = agent_data_center_instance.instance_id
      load_agent.public_ip_address = agent_data_center_instance.public_ip_address
      load_agent.private_ip_address = agent_data_center_instance.private_ip_address

      # SSH is available a while later even though status may be running
      logger.info { "agent##{load_agent.identifier} is running, ensuring SSH access..." }
      sleep(120)
      logger.debug { "sleep over..."}
      Hailstorm::Support::SSH.ensure_connection(load_agent.public_ip_address,
                                                self.user_name, ssh_options)

    end
  end

  # stop the load agent
  def stop_agent(load_agent)
    logger.debug { "#{self.class}##{__method__}" }
    unless load_agent.identifier.nil?
      agent_data_center_instance = data_center.instances[load_agent.identifier]
      if :running == agent_data_center_instance.status
        logger.info("Stopping agent##{load_agent.identifier}...")
        agent_data_center_instance.stop()
        timeout_message("#{agent_data_center_instance.id} to stop") do
          wait_until { agent_data_center_instance.status.eql?(:stopped) }
        end
      end
    else
      logger.warn("Could not stop agent as identifier is not available")
    end
  end

  # @return [Hash] of SSH options
  # (see Hailstorm::Behavior::Clusterable#ssh_options)
  def ssh_options()
    @ssh_options ||= {:keys => identity_file_path()}
  end

  # Start load agents if not started
  # (see Hailstorm::Behavior::Clusterable#before_generate_load)
  def before_generate_load()

    logger.debug { "#{self.class}##{__method__}" }
    self.load_agents.where(:active => true).each do |agent|
      unless agent.running?
        start_agent(agent)
        agent.save!
      end
    end
  end

  # Terminate load agent
  # (see Hailstorm::Behavior::Clusterable#before_destroy_load_agent)
  def before_destroy_load_agent(load_agent)

    logger.debug { "#{self.class}##{__method__}" }
    agent_data_center_instance = data_center.instances[load_agent.identifier]
    if agent_data_center_instance.exists?
      logger.info("Terminating agent##{load_agent.identifier}...")
      agent_data_center_instance.terminate()
      timeout_message("#{agent_data_center_instance.id} to terminate") do
        wait_until { agent_data_center_instance.status.eql?(:terminated) }
      end
    else
      logger.warn("Agent ##{load_agent.identifier} does not exist on EC2")
    end
  end



  # Delete SSH key-pair and identity once all load agents have been terminated
  # (see Hailstorm::Behavior::Clusterable#cleanup)

  ### DO WE NEED THIS #############################################
  def cleanup()

    logger.debug { "#{self.class}##{__method__}" }
    if self.autogenerated_ssh_key?
      if self.load_agents(true).empty?
        key_pair = data_center.key_pairs[self.ssh_identity]
        if key_pair.exists?
          key_pair.delete()
          FileUtils.safe_unlink(identity_file_path)
        end
      end
    end
  end


  # (see Hailstorm::Behavior::Clusterable#slug)
  def slug()
    @slug ||= "#{self.class.name.demodulize.titlecase}, region: #{self.region}"
  end

  # (see Hailstorm::Behavior::Clusterable#public_properties)
  def public_properties()
    columns = [:region]
    self.attributes.symbolize_keys.slice(*columns)
  end

  # Purges the Amazon accounts used of Hailstorm related artifacts

  ################## NEED TO MODIFY ACCORDING TO SCHEMA
  def self.purge()
    self.group(:access_key, :secret_key)
    .select("access_key, secret_key")
    .each do |item|
      cleaner = Hailstorm::Support::AmazonAccountCleaner.new(
          :access_key_id => item.access_key,
          :secret_access_key => item.secret_key
      )
      regions = []
      self.where(:access_key => item.access_key, :secret_key => item.secret_key)
      .each do |record|
        record.update_column(:agent_ami, nil)
        regions.push(record.region)
      end
      cleaner.cleanup(false, regions)
    end
  end


  ######################### PRIVATE METHODS ####################################
  private

  #################### WE ARE NOY USING KEY FOR NOW SO WE DON'T NEED THESE FUNCTIONS
  # def identity_file_exists()
  #
  # end
  #
  # def identity_file_path()
  #
  # end
  #
  # def identity_file_name()
  #
  # end


  def set_defaults()
    self.security_group = Defaults::SECURITY_GROUP if self.security_group.blank?
    self.user_name ||= Defaults::SSH_USER
    self.instance_type ||= InstanceTypes::Hydrogen
    self.max_threads_per_agent ||= default_max_threads_per_agent()

    if self.ssh_identity.nil?
      self.ssh_identity = [Defaults::SSH_IDENTITY, Hailstorm.app_name].join('_')
      self.autogenerated_ssh_key = true
    end

  end


################################ NEED TO CHK WHAT CAN WE USE IN PLACE
  # creates the agent ami
  def create_agent_ami()

    # logger.debug { "#{self.class}##{__method__}" }
    # if self.active? and self.agent_ami.nil?
    #
    #   rexp = Regexp.compile(ami_id())
    #   # check if this region already has the AMI...
    #   logger.info { "Searching available AMI on #{self.region}..."}
    #   ec2.images()
    #   .with_owner(:self)
    #   .inject({}) {|acc, e| e.state == :available ? acc.merge(e.name => e.id) : acc}.each_pair do |name, id|
    #
    #     if rexp.match(name)
    #       self.agent_ami = id
    #       logger.info("Using AMI #{self.agent_ami} for #{self.region}...")
    #       break
    #     end
    #   end
    #
    #   if self.agent_ami.nil?
    #     # AMI does not exist
    #     logger.info("Creating agent AMI for #{self.region}...")
    #
    #     # Check if required JMeter version is present in our bucket
    #     begin
    #       jmeter_s3_object.content_length() # will fail if object does not exist
    #     rescue AWS::S3::Errors::NoSuchKey
    #       raise(Hailstorm::JMeterVersionNotFound.new(self.project.jmeter_version,
    #                                                  Defaults::BUCKET_NAME))
    #     end
    #
    #     # Check if the SSH security group exists, or create it
    #     security_group = find_or_create_security_group()
    #
    #     # Launch base AMI
    #     clean_instance = ec2.instances.create({
    #                                               :image_id => base_ami(),
    #                                               :key_name => self.ssh_identity,
    #                                               :security_groups => [security_group.name],
    #                                               :instance_type => self.instance_type
    #                                           }.merge(self.zone.nil? ? {} : {:availability_zone => self.zone}))
    #
    #     timeout_message("#{clean_instance.id} to start") do
    #       wait_until { clean_instance.exists? && clean_instance.status.eql?(:running) }
    #     end
    #
    #     begin
    #       logger.info { "Clean instance at #{self.region} running, ensuring SSH access..." }
    #       sleep(120)
    #       Hailstorm::Support::SSH.ensure_connection(clean_instance.public_ip_address,
    #                                                 self.user_name, ssh_options)
    #
    #       Hailstorm::Support::SSH.start(clean_instance.public_ip_address,
    #                                     self.user_name, ssh_options) do |ssh|
    #
    #         # install JAVA to /opt
    #         logger.info { "Installing Java for #{self.region} AMI..." }
    #         ssh.exec!("wget -q '#{java_download_url}' -O #{java_download_file()}")
    #         ssh.exec!("chmod +x #{java_download_file}")
    #         ssh.exec!("cd /opt && sudo #{self.user_home}/#{java_download_file}")
    #         ssh.exec!("sudo ln -s /opt/#{jre_directory()} /opt/jre")
    #         # modify /etc/environment
    #         env_local_copy = File.join(Hailstorm.tmp_path, current_env_file_name)
    #         ssh.download('/etc/environment', env_local_copy)
    #         new_env_copy = File.join(Hailstorm.tmp_path, new_env_file_name)
    #         File.open(env_local_copy, 'r') do |envin|
    #           File.open(new_env_copy, 'w') do |envout|
    #             envin.each_line do |linein|
    #               lineout = nil
    #               linein.strip!
    #               if linein =~ /^PATH/
    #                 components = /^PATH="(.+?)"/.match(linein)[1].split(':')
    #                 components.unshift('/opt/jre/bin') # trying to get it in the beginning
    #                 lineout = "PATH=\"#{components.join(':')}\""
    #
    #               else
    #                 lineout = linein
    #               end
    #
    #               envout.puts(lineout) unless lineout.blank?
    #             end
    #             envout.puts "export JRE_HOME=/opt/jre"
    #             envout.puts "export CLASSPATH=/opt/jre/lib:."
    #           end
    #         end
    #         ssh.upload(new_env_copy, "#{self.user_home}/environment")
    #         File.unlink(new_env_copy)
    #         File.unlink(env_local_copy)
    #         ssh.exec!("sudo mv -f #{self.user_home}/environment /etc/environment")
    #
    #         # install JMeter to self.user_home
    #         logger.info { "Installing JMeter for #{self.region} AMI..." }
    #         ssh.exec!("wget -q '#{jmeter_download_url}' -O #{jmeter_download_file}")
    #         ssh.exec!("tar -xzf #{jmeter_download_file}")
    #         ssh.exec!("ln -s #{self.user_home}/#{jmeter_directory} #{self.user_home}/jmeter")
    #
    #       end # end ssh
    #
    #       # create the AMI
    #       logger.info { "Finalizing changes for #{self.region} AMI..." }
    #       new_ami = ec2.images.create(
    #           :name => ami_id,
    #           :instance_id => clean_instance.instance_id,
    #           :description => "AMI for distributed performance testing with JMeter (TSG)"
    #       )
    #       sleep(DOZE_TIME*12) while new_ami.state == :pending
    #
    #       if new_ami.state == :available
    #         self.agent_ami = new_ami.id
    #         logger.info { "New AMI##{self.agent_ami} on #{self.region} created successfully, cleaning up..."}
    #       else
    #         raise(Hailstorm::AmiCreationFailure.new(self.region, new_ami.state_reason))
    #       end
    #
    #     rescue
    #       logger.error("Failed to create instance on #{self.region}, terminating temporary instance...")
    #       raise
    #     ensure
    #       # ensure to terminate running instance
    #       clean_instance.terminate()
    #       sleep(DOZE_TIME) until clean_instance.status.eql?(:terminated)
    #     end
    #
    #   end # self.agent_ami.nil?
    # end # self.active? and self.agent_ami.nil?
  end

  # def find_or_create_security_group()
  #
  #   logger.debug { "#{self.class}##{__method__}" }
  #   security_group = ec2.security_groups
  #   .filter('group-name', Defaults::SECURITY_GROUP)
  #   .first()
  #   if security_group.nil?
  #     logger.info("Creating #{Defaults::SECURITY_GROUP} security group on #{self.region}...")
  #     security_group = ec2.security_groups.create(Defaults::SECURITY_GROUP,
  #                                                 :description => Defaults::SECURITY_GROUP_DESC)
  #
  #     security_group.authorize_ingress(:tcp, 22) # allow SSH from anywhere
  #     # allow incoming TCP to any port within the group
  #     security_group.authorize_ingress(:tcp, 0..65535, :group_id => security_group.id)
  #     # allow incoming UDP to any port within the group
  #     security_group.authorize_ingress(:udp, 0..65535, :group_id => security_group.id)
  #     # allow ICMP from anywhere
  #     security_group.allow_ping()
  #   end
  #
  #   return security_group
  # end



  def data_center
    @data_center ||= AWS::EC2.new(aws_config)
    .regions[self.region]
  end

  ##################### NEED TO CHK
  def s3()
    @s3 ||= AWS::S3.new(aws_config)
  end


  def java_download_url()
    @java_download_url ||= s3_bucket().objects[java_download_file_path()]
    .public_url(:secure => false)
  end

  def jmeter_download_url()
    @jmeter_download_url ||= jmeter_s3_object().public_url(:secure => false)
  end

  def jmeter_s3_object()
    s3_bucket().objects[jmeter_download_file_path]
  end

  def s3_bucket()
    @s3_bucket ||= s3.buckets[Defaults::BUCKET_NAME]
  end

  ######################## WE DON'T NEED THIS WE DON'T HAVE ZONES
  # def set_availability_zone()
  #
  # end


  def jmeter_download_file()
    "#{jmeter_directory}.tgz"
  end

  # Path relative to S3 bucket
  def jmeter_download_file_path()
    "open-source/#{jmeter_download_file}"
  end

  # Expanded JMeter directory
  def jmeter_directory
    version = self.project.jmeter_version
    "#{version == '2.4' ? 'jakarta' : 'apache'}-jmeter-#{version}"
  end

  # Architecture as per instance_type - i386 or x86_64, if internal is true,
  # 32-bit or 64-bit. Everything other than m1.small instance_type is x86_64.
  def arch(internal = false)

    if self.instance_type == InstanceTypes::Hydrogen
      internal ? '32-bit' : 'i386'
    else
      internal ? '64-bit' : 'x86_64'
    end
  end

  ################# NEED TO CHK AND CHANGE ACCORDINGLY
  # The AMI ID to search for and create
  # def ami_id
  #   "#{Defaults::AMI_ID}-j#{self.project.jmeter_version}-#{arch()}"
  # end

  # # Base AMI to use to create Hailstorm AMI based on the region and instance_type
  # # @return [String] Base AMI ID
  # def base_ami()
  #   region_base_ami_map[self.region][arch(true)]
  # end

  ############################## WE DON't NEED THIS
  # def region_base_ami_map()
  #
  # end

  def java_download_file()
    @java_download_file ||= {
        '32-bit' => 'jre-6u31-linux-i586.bin',
        '64-bit' => 'jre-6u33-linux-x64.bin'
    }[arch(true)]
  end

  def java_download_file_path()
    "open-source/#{java_download_file()}"
  end

  def jre_directory()
    @jre_directory ||= {
        '32-bit' => 'jre1.6.0_31',
        '64-bit' => 'jre1.6.0_33'
    }[arch(true)]
  end

  def instance_type_supported()

    unless InstanceTypes.valid?(self.instance_type)
      errors.add(:instance_type,
                 "not in supported list (#{InstanceTypes.allowed})")
    end
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

  def default_max_threads_per_agent()
    @default_max_threads_per_agent ||= {
        InstanceTypes::Hydrogen => 50,
        InstanceTypes::Calcium => 200,
        InstanceTypes::Ebony => 800,
        InstanceTypes::Steel => 1000
    }
    @default_max_threads_per_agent[self.instance_type]
  end

  # EC2 default settings
  class Defaults
    AMI_ID              = "brickred-hailstorm"
    SECURITY_GROUP      = "Hailstorm"
    SECURITY_GROUP_DESC = "Allows traffic to port 22 from anywhere and internal TCP, UDP and ICMP traffic"
    BUCKET_NAME         = 'brickred-perftest'
    SSH_USER            = 'ubuntu'
    SSH_IDENTITY        = 'hailstorm'
  end

  ######################### CHECK ONCE, NEED TO ADD SETTINGS FOR DATA CENTERS
  class InstanceTypes
    Hydrogen = 'm1.small'
    Calcium  = 'm1.large'
    Ebony    = 'm1.xlarge'
    Steel    = 'c1.xlarge'
    # HVM cluster compute instances are not supported due to limited availability
    # (only on us-east-1), different operating system and creation strategy
    # Titanium = 'cc1.4xlarge'
    # Diamond  = 'cc2.8xlarge'

    def self.valid?(instance_type)
      self.allowed.include?(instance_type)
    end

    def self.allowed()
      self.constants()
      .collect {|c| eval("#{self.name}::#{c}") }
    end

  end





end