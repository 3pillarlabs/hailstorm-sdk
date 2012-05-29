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

  validate :identity_file_exists, :if => proc {|r| r.active?}
  
  before_validation :set_defaults
  
  before_update :dirty_region_check, :create_agent_ami
  
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
          :image_id => self.agent_ami,
          :availability_zone => self.zone,
          :key_name => self.ssh_identity,
          :security_groups => self.security_group.split(/\s*,\s*/)
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

  # process the suspend option
  # (see Hailstorm::Behavior::Clusterable#after_stop_load_generation)
  def after_stop_load_generation()
    
    logger.debug { "#{self.class}##{__method__}" }
    if Hailstorm.application.command_processor.suspend_load_agents?
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
    logger.info("Terminating agent##{load_agent.identifier}...")
    agent_ec2_instance = ec2.instances[load_agent.identifier]
    agent_ec2_instance.terminate()
    sleep(DozeTime) until agent_ec2_instance.status.eql?(:terminated)
  end

  # (see Hailstorm::Behavior::Clusterable#slug)
  def slug()
    @slug ||= "#{self.class.name.demodulize.titlecase}, region: #{self.region}, zone: #{self.zone}"
  end

  # (see Hailstorm::Behavior::Clusterable#public_properties)
  def public_properties()
    columns = [:access_key, :secret_key, :ssh_identity,
    :region, :zone, :agent_ami, :user_name, :security_group]
    self.attributes.symbolize_keys.slice(*columns).to_json
  end

######################### PRIVATE METHODS ####################################  
  private
  
  def identity_file_exists()
    unless File.exists?(identity_file_path)
      errors.add(:ssh_identity, "not found at #{identity_file_path}")
    else
      unless File.file?(identity_file_path) # regular file check
        errors.add(:ssh_identity, "at #{identity_file_path} must be a regular file")
      end
    end
  end
  
  def identity_file_path()
    @identity_file_path ||= File.join(Hailstorm.root, Hailstorm.db_dir,
              self.ssh_identity.gsub(/\.pem/, '').concat('.pem'))
  end

  def set_defaults()
    self.security_group = Defaults::SecurityGroup if self.security_group.blank?
    self.user_name ||= Defaults::SSH_USER
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
      
      rexp = Regexp.compile(ami_id)
      # check if this region already has the AMI...
      logger.info { "Searching available AMI..."}
      ec2.images
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
                "JMeter version #{self.project.jmeter_version} not found in #{Defaults::BucketName} bucket")
        end
        
        # Check if the SSH security group exists, or create it
        security_group = find_or_create_security_group()
        
        # Launch base AMI
        clean_instance = ec2.instances.create(
          :image_id => Defaults::BaseAMI,
          :availability_zone => self.zone,
          :key_name => self.ssh_identity,
          :security_groups => [security_group.name]
        )
        sleep(DozeTime) until clean_instance.status.eql?(:running)
        
        begin
          logger.info { "Clean instance running, ensuring SSH access..." }
          sleep(120)
          Hailstorm::Support::SSH.ensure_connection(clean_instance.public_ip_address,
            self.user_name, ssh_options)

          Hailstorm::Support::SSH.start(clean_instance.public_ip_address,
            self.user_name, ssh_options) do |ssh|
              
            # update APT packages          
            logger.info { "Updating APT sources..." }
            command = 'export DEBIAN_FRONTEND=noninteractive && sudo apt-get update -y && sudo apt-get upgrade -y'
            stderr = ''  
            ssh.exec!(command) do |channel, stream, data|
              if :stderr == stream
                stderr << data
              else
                print(data) if logger.debug?
              end
            end
            unless stderr.blank?
              logger.warn("Possible errors while updating APT sources, please review:\n#{stderr}")            
            end
            
            # install JAVA to /opt
            logger.info { "Installing Java..." }
            ssh.exec!("wget -q '#{java_download_url}' -O #{Defaults::JavaDownloadFile}")
            ssh.exec!("chmod +x #{Defaults::JavaDownloadFile}")
            command = "cd /opt && sudo #{self.user_home}/#{Defaults::JavaDownloadFile}"
            stderr = ''
            ssh.exec!(command) do |channel, stream, data|
              if :stderr == stream
                stderr << data
              else
                print(data) if logger.debug?
              end
            end
            raise(stderr) unless stderr.blank?
            ssh.exec!("sudo ln -s /opt/#{Defaults::JreDirectory} /opt/jre")
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
                        .filter('group-name', Defaults::SecurityGroup)
                        .first()     
    if security_group.nil?
      logger.info("Creating #{Defaults::SecurityGroup} security group...")
      security_group = ec2.security_groups.create(Defaults::SecurityGroup, 
                        :description => Defaults::SecurityGroupDesc)
      
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
    
    if @ec2.nil?
      simulate = false # for debugging purpose
      unless simulate
        @ec2 = AWS::EC2.new(aws_config)
                       .regions[self.region]
      else
        @ec2 = Object.new()
        
        def @ec2.instances
          @instances = Object.new()
          
          def @instances.create(*args)
            sleep(20)
            dummy_instance()
          end
          
          def @instances.[](id)
            sleep(3)
            dummy_instance()
          end
          
          def @instances.dummy_instance()
            @dummy = Object.new
            
            def @dummy.status
              sleep(10)
              :terminated
            end
            
            def @dummy.start
              sleep(20)
            end
            
            def @dummy.instance_id
              "i-89765"
            end
            
            def @dummy.public_ip_address
              "172.16.10.70"
            end
            
            def @dummy.stop
              sleep(10)
            end
            
            def @dummy.terminate
              sleep(5)
            end
          end
          
          @instances
        end
        
      end 
    end
    
    @ec2
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
    @java_download_url ||= s3_bucket().objects[Defaults::JavaDownloadFilePath]
                                      .url_for(:read)    
  end
  
  def jmeter_download_url()
    @jmeter_download_url ||= jmeter_s3_object().url_for(:read)
  end

  def jmeter_s3_object()
    s3_bucket().objects[jmeter_download_file_path]
  end

  def s3_bucket()
    @s3_bucket ||= s3.buckets[Defaults::BucketName]
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

  # The AMI ID to search for and create
  def ami_id
    "#{Defaults::AmiId}-j#{self.project.jmeter_version}-i386"
  end

  # EC2 default settings
  class Defaults
    
    AmiId                   = "brickred-hailstorm"
    SecurityGroup           = "Hailstorm"
    SecurityGroupDesc       = "Allows traffic to port 22 from anywhere and internal TCP, UDP and ICMP traffic"
    BaseAMI                 = 'ami-714ba518'
    BucketName              = 'brickred-perftest'
    JavaDownloadFile        = 'jre-6u31-linux-i586.bin'
    JavaDownloadFilePath    = "open-source/#{JavaDownloadFile}"
    JreDirectory            = 'jre1.6.0_31'
    SSH_USER                = 'ubuntu'

  end
    
end
