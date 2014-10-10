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

  validates_presence_of :user_name, :ip_address, :ssh_identity
  validate :ip_address, format:{ with:/^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$/}

  before_save :provision_datacenter_agents#, :if => proc {|r| r.ssh_identity.nil?}

  after_destroy :cleanup

  # Seconds between successive Data Center status checks
  DOZE_TIME = 5

  # Creates a data center load agent with all required packages pre-installed and
  # starts requisite number of instances
  def setup(force = false)
    logger.debug { "#{self.class}##{__method__}" }

    #TODO : remove this block, just for testing
    Hailstorm::Support::SSH.start(self.ip_address,
                                  self.user_name, ssh_options) do |ssh|
      output = ssh.exec!("ls /")
      puts output
    end
    if machine_status?
      puts "Machine status verified"
      if self.active?
        puts "Machine status active"
        self.save!()
        provision_agents()
      else
        puts "Machine status inactive"
        self.update_column(:active, false) if self.persisted?
      end
    else
      logger.warn("Invalid ssh identity file or machine not accessible")
      raise(Hailstorm::DataCenterAccessFailure.new(self.user_name, self.ip_address, self.ssh_identity))
    end
  end

  # start the agent and update agent ip_address and identifier
  def start_agent(load_agent)
    logger.debug { load_agent.attributes.inspect }
    if not self.ip_address.nil?
      # update attributes
      load_agent.identifier = self.datacenter_name
      load_agent.public_ip_address = self.ip_address
      load_agent.private_ip_address = self.ip_address
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
    @ssh_options ||= {:password => 'ubuntu' }
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
    agent_data_center_instance = data_center.instances[load_agent.identiiffier]
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
  end


  # (see Hailstorm::Behavior::Clusterable#slug)
  def slug()
    @slug ||= "#{self.class.name.demodulize.titlecase}, region: #{self.datacenter_name}"
  end

  # (see Hailstorm::Behavior::Clusterable#public_properties)
  def public_properties()
  end

  # Purges the Amazon accounts used of Hailstorm related artifacts

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
    self.ip_address ||= Defaults::IP_ADDRESS
    self.machine_type ||= Defaults::MACHINE_TYPE
    self.datacenter_name ||= Defaults::DATACENTER_NAME
    self.max_threads_per_machine ||= default_max_threads_per_machine()
    if self.ssh_identity.nil?
      self.ssh_identity = [Defaults::SSH_IDENTITY, Hailstorm.app_name].join('_')
    end
  end

  def machine_status?
    #check if Hailstorm can SSH to specified machine
    #logger.info("Checking SSH connectivity status")
    status = Hailstorm::Support::SSH.ensure_connection(self.ip_address,
                                                               self.user_name, ssh_options)
    #starself.update_column(:active, status)
    return status
  end

  def provision_datacenter_agents()
    logger.debug { "#{self.class}##{__method__}" }
    # check if Hailstorm can connect to machine using SSH...
    logger.info { "Looking up if Hailstorm can connect datacenter machine through SSH..."}
    if machine_status?
      # Check if required JMeter version is present in our bucket
      begin
        jmeter_s3_object.content_length() # will fail if object does not exist
      rescue AWS::S3::Errors::NoSuchKey
        raise(Hailstorm::JMeterVersionNotFound.new(self.project.jmeter_version,
                                                   Defaults::BUCKET_NAME))
      end
      begin
        sleep(120)
        puts "Installing required software on target machine"
        #if Hailstorm::Support::SSH.ensure_connection(self.ip_address,self.user_name, ssh_options)

          Hailstorm::Support::SSH.start(self.ip_address,self.user_name, ssh_options) do |ssh|

            # install JAVA to /opt
            ssh.exec!("wget -q '#{java_download_url}' -O #{java_download_file()}")
            ssh.exec!("chmod +x #{java_download_file}")
            ssh.exec!("cd /opt && sudo #{self.user_home}/#{java_download_file}")
            ssh.exec!("sudo ln -s /opt/#{jre_directory()} /opt/jre")
            # modify /etc/environment
            env_local_copy = File.join(Hailstorm.tmp_path, current_env_file_name)
            ssh.download('/etc/environment', env_local_copy)
            new_env_copy = File.join(Hailstorm.tmp_path, new_env_file_name)
            File.open(env_local_copy, 'r') do |envin|
              File.open(new_env_copy, 'w') do |envout|
                envin.each_line do |linein|
                  lineout = nil
                  linein.strip!
                  if linein =~ /^PATH/
                    components = /^PATH="(.+?)"/.match(linein)[1].split(':')
                    components.unshift('/opt/jre/bin') # trying to get it in the beginning
                    lineout = "PATH=\"#{components.join(':')}\""

                  else
                    lineout = linein
                  end
                  envout.puts(lineout) unless lineout.blank?
                end
                envout.puts "export JRE_HOME=/opt/jre"
                envout.puts "export CLASSPATH=/opt/jre/lib:."
              end
            end
            ssh.upload(new_env_copy, "#{self.user_home}/environment")
            File.unlink(new_env_copy)
            File.unlink(env_local_copy)
            ssh.exec!("sudo mv -f #{self.user_home}/environment /etc/environment")

            # install JMeter to self.user_home
            logger.info { "Installing JMeter for #{self.region} AMI..." }
            ssh.exec!("wget -q '#{jmeter_download_url}' -O #{jmeter_download_file}")
            ssh.exec!("tar -xzf #{jmeter_download_file}")
            ssh.exec!("ln -s #{self.user_home}/#{jmeter_directory} #{self.user_home}/jmeter")

          end # end ssh
        #end
      rescue  Exception => e
        puts e.message
        logger.error("Failed to connect to specified datacenter machine...")
        raise(Hailstorm::DataCenterAccessFailure.new(self.user_name, self.ip_address, self.ssh_identity))
      ensure
        #Ensure cleanup
    end
    else
      raise(Hailstorm::DataCenterAccessFailure.new(self.user_name, self.ip_address, self.ssh_identity))
    end
  end

  def ec2
    @ec2 ||= AWS::EC2.new(aws_config)
    .regions[self.region]
  end

  def s3()
    @s3 ||= AWS::S3.new(aws_config)
  end

  def aws_config()
    @aws_config ||= {
        :access_key_id => self.aws_access_key,
        :secret_access_key => self.aws_secret_key,
        :max_retries => 3,
        :logger => logger
    }
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
      internal ? '64-bit' : 'x86_64'
  end

  ################# NEED TO CHK AND CHANGE ACCORDINGLY


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

  def default_max_threads_per_machine()
    @default_max_threads_per_machine ||= 100
  end

  # Data center default settings
  class Defaults
    BUCKET_NAME         = 'brickred-perftest'
    SSH_USER            = 'ubuntu'
    SSH_IDENTITY        = 'server.pem'
    MACHINE_TYPE        = '64-bit'
    IP_ADDRESS          = '127.0.0.1'
    DATACENTER_NAME     = 'Hailstorm'
  end

  # class SSHHelper
  #   def agent_status()
  #
  #   end
  # end

end