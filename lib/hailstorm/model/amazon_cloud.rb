# AmazonCloud model - models the configuration for creating load agent AMI
# on the Amazon EC2 cloud.
# @author Sayantam Dey

require 'aws'
require 'hailstorm'
require 'hailstorm/model'
require 'hailstorm/behavior/clusterable'
require 'hailstorm/support/ssh'

class Hailstorm::Model::AmazonCloud < ActiveRecord::Base
  
  include Hailstorm::Behavior::Clusterable

  before_validation :set_defaults

  validates_presence_of :access_key, :secret_key, :region

  validate :identity_file_exists, :if => proc {|r| r.active?}

  validate :instance_type_supported, :if => proc {|r| r.active?}

  before_create :set_availability_zone, :if => proc {|r| r.zone.blank?}

  before_update :dirty_region_check, :create_agent_ami

  after_destroy :cleanup

  # Seconds between successive EC2 status checks 
  DozeTime = 5
  
  # Creates an load agent AMI with all required packages pre-installed and
  # starts requisite number of instances
  def setup(config_attributes)
    
    logger.debug { "#{self.class}##{__method__}" }
    self.update_attributes!(config_attributes)
    if active?
      File.chmod(0400, identity_file_path())  
    end    
  end
  
  # start the agent and update agent ip_address and identifier
  def start_agent(load_agent)
    
    logger.debug { load_agent.attributes.inspect }
    unless load_agent.running?
      agent_ec2_instance = nil
      unless load_agent.identifier.nil?
        agent_ec2_instance = ec2.instances[load_agent.identifier]
        if :stopped == agent_ec2_instance.status
          logger.info("Restarting agent##{load_agent.identifier}...")
          agent_ec2_instance.start()
          sleep(DozeTime) until agent_ec2_instance.status.eql?(:running)
        end
      else
        logger.info("Starting new agent on #{self.region}...")
        agent_ec2_instance = ec2.instances.create(
          {:image_id => self.agent_ami,
          :key_name => self.ssh_identity,
          :security_groups => self.security_group.split(/\s*,\s*/),
          :instance_type => self.instance_type}.merge(
              self.zone.nil? ? {} : {:availability_zone => self.zone}
          )
        )
        sleep(DozeTime) until agent_ec2_instance.status.eql?(:running)
      end
      
      # update attributes
      load_agent.identifier = agent_ec2_instance.instance_id
      load_agent.public_ip_address = agent_ec2_instance.public_ip_address
      load_agent.private_ip_address = agent_ec2_instance.private_ip_address
      
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
      agent_ec2_instance = ec2.instances[load_agent.identifier]
      if :running == agent_ec2_instance.status
        logger.info("Stopping agent##{load_agent.identifier}...")
        agent_ec2_instance.stop()
        sleep(DozeTime) until agent_ec2_instance.status.eql?(:stopped)
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
        agent.start_agent()
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
          agent.stop_agent()
          agent.save!
        end
      end
    end    
  end
  
  # Terminate load agent
  # (see Hailstorm::Behavior::Clusterable#before_destroy_load_agent)
  def before_destroy_load_agent(load_agent)
    
    logger.debug { "#{self.class}##{__method__}" }
    agent_ec2_instance = ec2.instances[load_agent.identifier]
    if agent_ec2_instance.exists?
      logger.info("Terminating agent##{load_agent.identifier}...")
      agent_ec2_instance.terminate()
      sleep(DozeTime) until agent_ec2_instance.status.eql?(:terminated)
    else
      logger.warn("Agent ##{load_agent.identifier} does not exist on EC2")
    end
  end

  # Delete SSH key-pair and identity once all load agents have been terminated
  # (see Hailstorm::Behavior::Clusterable#cleanup)
  def cleanup()

    logger.debug { "#{self.class}##{__method__}" }
    if self.autogenerated_ssh_key?
      if self.load_agents(true).empty?
        key_pair = ec2.key_pairs[self.ssh_identity]
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

######################### PRIVATE METHODS ####################################  
  private
  
  def identity_file_exists()

    unless File.exists?(identity_file_path)
      key_pair = ec2.key_pairs[self.ssh_identity]
      unless key_pair.exists? # check if the identity is already defined in EC2 region
        logger.debug { "Creating #{self.ssh_identity} key_pair..." }
        key_pair = ec2.key_pairs.create(self.ssh_identity)
        File.open(identity_file_path(), 'w') do |file|
          file.print(key_pair.private_key)
        end
      else
        # can't get private_key of key_pair which has been created externally,
        # user needs to place the file manually
        errors.add(:ssh_identity, "not found at #{identity_file_path}")
      end
    else
      unless File.file?(identity_file_path) # is it a regular file?
        errors.add(:ssh_identity, "at #{identity_file_path} must be a regular file")
      end
    end
  end
  
  def identity_file_path()
    @identity_file_path ||= File.join(Hailstorm.root, Hailstorm.db_dir,
                                      identity_file_name())
  end

  def identity_file_name()
    [self.ssh_identity.gsub(/\.pem/, ''), self.region].join('_').concat('.pem')
  end


  def set_defaults()
    self.security_group = Defaults::SECURITY_GROUP if self.security_group.blank?
    self.user_name ||= Defaults::SSH_USER
    self.instance_type ||= InstanceTypes::Hydrogen

    if self.ssh_identity.nil?
      self.ssh_identity = [Defaults::SSH_IDENTITY, Hailstorm.app_name].join('_')
      self.autogenerated_ssh_key = true
    end

  end

  # checks if the region attribute is dirty, if so nils out the agent_mi.
  def dirty_region_check()

    logger.debug { "#{self.class}##{__method__}" }
    self.agent_ami = nil if self.region_changed? 
  end
  
  # creates the agent ami
  def create_agent_ami()

    logger.debug { "#{self.class}##{__method__}" }
    if self.active? and self.agent_ami.nil?
      
      rexp = Regexp.compile(ami_id())
      # check if this region already has the AMI...
      logger.info { "Searching available AMI..."}
      ec2.images()
         .with_owner(:self)
         .inject({}) {|acc, e| acc.merge(e.name => e.id)}.each_pair do |name, id|
      
        if rexp.match(name)
          self.agent_ami = id
          logger.info("Using AMI #{self.agent_ami} for agents...")
          break          
        end 
      end
      
      if self.agent_ami.nil?
        # AMI does not exist
        logger.info("Creating agent AMI for #{self.region}...")

        # Check if required JMeter version is present in our bucket
        begin
          jmeter_s3_object.content_length() # will fail if object does not exist
        rescue AWS::S3::Errors::NoSuchKey
          raise(Hailstorm::Error,
                "JMeter version #{self.project.jmeter_version} not found in #{Defaults::BUCKET_NAME} bucket")
        end
        
        # Check if the SSH security group exists, or create it
        security_group = find_or_create_security_group()
        
        # Launch base AMI
        clean_instance = ec2.instances.create({
          :image_id => base_ami(),
          :key_name => self.ssh_identity,
          :security_groups => [security_group.name],
          :instance_type => self.instance_type
        }.merge(self.zone.nil? ? {} : {:availability_zone => self.zone}))
        sleep(DozeTime) until clean_instance.status.eql?(:running)
        
        begin
          logger.info { "Clean instance running, ensuring SSH access..." }
          sleep(120)
          Hailstorm::Support::SSH.ensure_connection(clean_instance.public_ip_address,
            self.user_name, ssh_options)

          Hailstorm::Support::SSH.start(clean_instance.public_ip_address,
            self.user_name, ssh_options) do |ssh|
              
            # update APT packages - deemed extraneous since we are not using any packaged software anyway!
            #logger.info { "Updating APT sources..." }
            #command = 'export DEBIAN_FRONTEND=noninteractive && sudo apt-get update -y && sudo apt-get upgrade -y'
            #stderr = ''
            #ssh.exec!(command) do |channel, stream, data|
            #  if :stderr == stream
            #    stderr << data
            #  else
            #    print(data) if logger.debug?
            #  end
            #end
            #unless stderr.blank?
            #  logger.warn("Possible errors while updating APT sources, please review:\n#{stderr}")
            #end
            
            # install JAVA to /opt
            logger.info { "Installing Java..." }
            ssh.exec!("wget -q '#{java_download_url}' -O #{java_download_file()}")
            ssh.exec!("chmod +x #{java_download_file}")
            command = "cd /opt && sudo #{self.user_home}/#{java_download_file}"
            stderr = ''
            ssh.exec!(command) do |channel, stream, data|
              if :stderr == stream
                stderr << data
              else
                print(data) if logger.debug?
              end
            end
            raise(stderr) unless stderr.blank?
            ssh.exec!("sudo ln -s /opt/#{jre_directory()} /opt/jre")
            # modify /etc/environment
            ssh.download('/etc/environment', "#{Hailstorm.tmp_path}/environment~")
            File.open("#{Hailstorm.tmp_path}/environment~", 'r') do |envin|
              File.open("#{Hailstorm.tmp_path}/environment", 'w') do |envout|
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
            ssh.upload("#{Hailstorm.tmp_path}/environment", "#{self.user_home}/environment")
            File.unlink("#{Hailstorm.tmp_path}/environment")
            File.unlink("#{Hailstorm.tmp_path}/environment~")
            ssh.exec!("sudo mv -f #{self.user_home}/environment /etc/environment")
            
            # install JMeter to self.user_home
            logger.info { "Installing JMeter..." }
            ssh.exec!("wget -q '#{jmeter_download_url}' -O #{jmeter_download_file}")
            ssh.exec!("tar -xzf #{jmeter_download_file}")
            ssh.exec!("ln -s #{self.user_home}/#{jmeter_directory} #{self.user_home}/jmeter")
            
          end # end ssh
          
          # create the AMI
          logger.info { "Finalizing changes..." } 
          new_ami = ec2.images.create(
            :name => ami_id,
            :instance_id => clean_instance.instance_id,
            :description => "AMI for distributed performance testing with JMeter (TSG)"
          )
          sleep(DozeTime*12) while new_ami.state == :pending
          
          if new_ami.state == :available
            self.agent_ami = new_ami.id
            logger.info { "New AMI created successfully, cleaning up..."} 
          else
            raise(StandardError, "AMI could not be created, reason unknown")
          end 
          
        rescue
          logger.error("Failed to create instance, terminating temporary instance...")
          raise
        ensure
          # ensure to terminate running instance
          clean_instance.terminate()
          sleep(DozeTime) until clean_instance.status.eql?(:terminated)
        end
        
      end # self.agent_ami.nil?
    end # self.active? and self.agent_ami.nil?
  end

  def find_or_create_security_group()

    logger.debug { "#{self.class}##{__method__}" }
    security_group = ec2.security_groups
                        .filter('group-name', Defaults::SECURITY_GROUP)
                        .first()     
    if security_group.nil?
      logger.info("Creating #{Defaults::SECURITY_GROUP} security group...")
      security_group = ec2.security_groups.create(Defaults::SECURITY_GROUP,
                        :description => Defaults::SECURITY_GROUP_DESC)
      
      security_group.authorize_ingress(:tcp, 22) # allow SSH from anywhere
      # allow incoming TCP to any port within the group
      security_group.authorize_ingress(:tcp, 0..65535, :group_id => security_group.id)
      # allow incoming UDP to any port within the group
      security_group.authorize_ingress(:udp, 0..65535, :group_id => security_group.id)
      # allow ICMP from anywhere
      security_group.allow_ping()
    end
    
    return security_group
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
      :access_key_id => self.access_key,
      :secret_access_key => self.secret_key,
      :max_retries => 3,
      :logger => Hailstorm.subsystem_logger
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

  # Sets the first available zone based on configured region
  # only if the project is configured in master slave mode
  def set_availability_zone()

    logger.debug { "#{self.class}##{__method__}" }
    if self.project.master_slave_mode?
      ec2.availability_zones.each do |z|
        if z.state == :available
          self.zone = z.name
          break
        end
      end
    end
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

    if self.instance_type == InstanceTypes::Hydrogen
      internal ? '32-bit' : 'i386'
    else
      internal ? '64-bit' : 'x86_64'
    end
  end

  # The AMI ID to search for and create
  def ami_id
    "#{Defaults::AMI_ID}-j#{self.project.jmeter_version}-#{arch()}"
  end

  # Base AMI to use to create Hailstorm AMI based on the region and instance_type
  # @return [String] Base AMI ID
  def base_ami()
    region_base_ami_map[self.region][arch(true)]
  end

  # Static map of regions, architectures and AMI ID of latest stable Ubuntu LTS
  # AMIs (Precise Pangolin - http://cloud-images.ubuntu.com/releases/precise/release/).
  def region_base_ami_map()
    @region_base_ami_map ||= {
      'ap-northeast-1' => { # Asia Pacific (Tokyo)
          '64-bit' => 'ami-60c77761',
          '32-bit' => 'ami-5ec7775f'
      },
      'ap-southeast-1' => { # Asia Pacific (Singapore)
          '64-bit' => 'ami-a4ca8df6',
          '32-bit' => 'ami-a6ca8df4'
      },
      'eu-west-1' => {  # Europe West (Ireland)
          '64-bit' => 'ami-e1e8d395',
          '32-bit' => 'ami-e7e8d393'
      },
      'sa-east-1' => { # South America (Sao Paulo)
          '64-bit' => 'ami-8cd80691',
          '32-bit' => 'ami-92d8068f'
      },
      'us-east-1' => { # US East (Virginia)
          '64-bit' => 'ami-a29943cb',
          '32-bit' => 'ami-ac9943c5'
      },
      'us-west-1' => { # US West (N. California)
          '64-bit' => 'ami-87712ac2',
          '32-bit' => 'ami-85712ac0'
      },
      'us-west-2' => { # US West (Oregon)
          '64-bit' => 'ami-20800c10',
          '32-bit' => 'ami-3e800c0e'
      }
    }
  end

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

  # EC2 default settings
  class Defaults
    AMI_ID              = "brickred-hailstorm"
    SECURITY_GROUP      = "Hailstorm"
    SECURITY_GROUP_DESC = "Allows traffic to port 22 from anywhere and internal TCP, UDP and ICMP traffic"
    BUCKET_NAME         = 'brickred-perftest'
    SSH_USER            = 'ubuntu'
    SSH_IDENTITY        = 'hailstorm'
  end

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
