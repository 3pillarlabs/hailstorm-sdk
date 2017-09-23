# @author Sayantam Dey

require 'aws'

require 'hailstorm'
require 'hailstorm/model'
require 'hailstorm/behavior/clusterable'
require 'hailstorm/support/ssh'
require 'hailstorm/support/amazon_account_cleaner'

class Hailstorm::Model::AmazonCloud < ActiveRecord::Base

  include Hailstorm::Behavior::Clusterable

  before_validation :set_defaults

  validates_presence_of :access_key, :secret_key, :region

  validate :identity_file_exists, :if => proc {|r| r.active?}

  before_save :set_availability_zone, :if => proc {|r| r.active?}

  before_save :create_agent_ami, :if => proc {|r| r.active? and r.agent_ami.nil?}

  after_destroy :cleanup

  # Seconds between successive EC2 status checks
  DOZE_TIME = 5

  # Creates an load agent AMI with all required packages pre-installed and
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
      agent_ec2_instance = nil
      unless load_agent.identifier.nil?
        agent_ec2_instance = ec2.instances[load_agent.identifier]
        if :stopped == agent_ec2_instance.status
          logger.info("Restarting agent##{load_agent.identifier}...")
          agent_ec2_instance.start()
          timeout_message("#{agent_ec2_instance.id} to restart") do
            wait_until { agent_ec2_instance.status.eql?(:running) }
          end
        end
      else
        logger.info("Starting new agent on #{self.region}...")
        security_group_ids = self.security_group.split(/\s*,\s*/).map { |x| find_or_create_security_group(x) }.map(&:id)
        agent_ec2_instance = create_ec2_instance(self.agent_ami, security_group_ids)
        agent_ec2_instance.tag('Name', value: "#{self.project.project_code}-#{load_agent.class.name.underscore}-#{load_agent.id}")
        timeout_message("#{agent_ec2_instance.id} to start") do
          wait_until { agent_ec2_instance.exists? && agent_ec2_instance.status.eql?(:running) }
        end
      end

      load_agent.ec2_instance = agent_ec2_instance
      # update attributes
      load_agent.identifier = agent_ec2_instance.instance_id
      load_agent.public_ip_address = agent_ec2_instance.public_ip_address
      load_agent.private_ip_address = agent_ec2_instance.private_ip_address

      # reachability checks
      logger.info { "agent##{load_agent.identifier} is running, waiting for system checks..." }
      wait_for_system_checks(load_agent, "system checks on agent##{load_agent.identifier} to complete")

      # SSH is available a while later even though status may be running
      logger.info { "agent##{load_agent.identifier} passed system checks, ensuring SSH access..." }
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
        timeout_message("#{agent_ec2_instance.id} to stop") do
          wait_until { agent_ec2_instance.status.eql?(:stopped) }
        end
        load_agent.ec2_instance = nil
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

  # Terminate load agent
  # (see Hailstorm::Behavior::Clusterable#before_destroy_load_agent)
  def before_destroy_load_agent(load_agent)

    logger.debug { "#{self.class}##{__method__}" }
    agent_ec2_instance = ec2.instances[load_agent.identifier]
    if agent_ec2_instance.exists?
      logger.info("Terminating agent##{load_agent.identifier}...")
      agent_ec2_instance.terminate()
      timeout_message("#{agent_ec2_instance.id} to terminate") do
        wait_until { agent_ec2_instance.status.eql?(:terminated) }
      end
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

  # Purges the Amazon accounts used of Hailstorm related artifacts
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

  def required_load_agent_count(jmeter_plan)

    if self.respond_to?(:max_threads_per_agent) and jmeter_plan.num_threads() > self.max_threads_per_agent
    (jmeter_plan.num_threads().to_f / self.max_threads_per_agent).ceil()
    else
      1
    end
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
    @identity_file_path ||= File.join(Hailstorm.root, Hailstorm.config_dir,
                                      identity_file_name())
  end

  def identity_file_name()
    [self.ssh_identity.gsub(/\.pem/, ''), self.region].join('_').concat('.pem')
  end


  def set_defaults()
    self.security_group = Defaults::SECURITY_GROUP if self.security_group.blank?
    self.user_name ||= Defaults::SSH_USER
    self.instance_type ||= Defaults::INSTANCE_TYPE
    self.max_threads_per_agent ||= default_max_threads_per_agent()

    if self.ssh_identity.nil?
      self.ssh_identity = [Defaults::SSH_IDENTITY, Hailstorm.app_name].join('_')
      self.autogenerated_ssh_key = true
    end

  end

  # creates the agent ami
  def create_agent_ami()

    logger.debug { "#{self.class}##{__method__}" }
    if self.active? and self.agent_ami.nil?

      rexp = Regexp.compile(ami_id)
      # check if this region already has the AMI...
      logger.info { "Searching available AMI on #{self.region}..." }
      ec2.images()
         .with_owner(:self)
         .inject({}) {|acc, e| e.state == :available ? acc.merge(e.name => e.id) : acc}.each_pair do |name, id|

        if rexp.match(name)
          self.agent_ami = id
          logger.info("Using AMI #{self.agent_ami} for #{self.region}...")
          break
        end
      end

      # Check if the SSH security group exists, or create it
      security_group = find_or_create_security_group()

      if self.agent_ami.nil?
        # AMI does not exist
        logger.info("Creating agent AMI for #{self.region}...")

        # Launch base AMI
        clean_instance = create_ec2_instance(base_ami, [security_group.id])

        timeout_message("#{clean_instance.id} to start") do
          wait_until { clean_instance.exists? && clean_instance.status.eql?(:running) }
        end

        begin
          logger.info { "Clean instance at #{self.region} running, ensuring SSH access..." }
          wait_for_system_checks(clean_instance, "system checks on instance##{clean_instance.identifier} to complete")
          Hailstorm::Support::SSH.ensure_connection(clean_instance.public_ip_address, self.user_name, ssh_options)

          Hailstorm::Support::SSH.start(clean_instance.public_ip_address, self.user_name, ssh_options) do |ssh|

            # install JAVA to /opt
            logger.info { "Installing Java for #{self.region} AMI..." }
            ssh.exec!("wget -q '#{java_download_url()}' -O #{java_download_file()}")
            if java_download_file.match(/\.bin$/)
              ssh.exec!("chmod +x #{java_download_file}")
              ssh.exec!("cd /opt && sudo #{self.user_home}/#{java_download_file}")
            elsif java_download_file.match(/\.tgz$/) or java_download_file.match(/\.tar\.gz$/)
              ssh.exec!("cd /opt && sudo tar -xzf #{self.user_home}/#{java_download_file}")
            else
              raise(Hailstorm::JavaInstallationException.new(self.region, java_download_file))
            end
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
                envout.puts 'export JRE_HOME=/opt/jre'
                envout.puts 'export CLASSPATH=/opt/jre/lib:.'
              end
            end
            ssh.upload(new_env_copy, "#{self.user_home}/environment")
            File.unlink(new_env_copy)
            File.unlink(env_local_copy)
            ssh.exec!("sudo mv -f #{self.user_home}/environment /etc/environment")

            # install JMeter to self.user_home
            unless self.project.custom_jmeter_installer_url
              # Check if required JMeter version is present in our bucket
              begin
                jmeter_s3_object.content_length() # will fail if object does not exist
              rescue AWS::S3::Errors::NoSuchKey
                raise(Hailstorm::JMeterVersionNotFound.new(self.project.jmeter_version,
                                                           Defaults::BUCKET_NAME, jmeter_download_file_path))
              end
            end
            logger.info { "Installing JMeter for #{self.region} AMI..." }
            ssh.exec!("wget -q '#{jmeter_download_url}' -O #{jmeter_download_file}")
            ssh.exec!("tar -xzf #{jmeter_download_file}")
            ssh.exec!("ln -s #{self.user_home}/#{jmeter_directory} #{self.user_home}/jmeter")

            jmeter_props_remote_path = "#{self.user_home}/jmeter/bin/user.properties"
            ssh.exec!("echo '# Added by Hailstorm' >> #{jmeter_props_remote_path}")
            ssh.exec!("echo 'jmeter.save.saveservice.output_format=xml' >> #{jmeter_props_remote_path}")
            ssh.exec!("echo 'jmeter.save.saveservice.hostname=true' >> #{jmeter_props_remote_path}")
            ssh.exec!("echo 'jmeter.save.saveservice.thread_counts=true' >> #{jmeter_props_remote_path}")

          end # end ssh

          # create the AMI
          logger.info { "Finalizing changes for #{self.region} AMI..." }
          new_ami = ec2.images.create(
            :name => ami_id,
            :instance_id => clean_instance.instance_id,
            :description => 'AMI for distributed performance testing with Hailstorm'
          )
          sleep(DOZE_TIME*12) while new_ami.state == :pending

          if new_ami.state == :available
            self.agent_ami = new_ami.id
            logger.info { "New AMI##{self.agent_ami} on #{self.region} created successfully, cleaning up..."}
          else
            raise(Hailstorm::AmiCreationFailure.new(self.region, new_ami.state_reason))
          end

        rescue
          logger.error("Failed to create instance on #{self.region}, terminating temporary instance...")
          raise
        ensure
          # ensure to terminate running instance
          clean_instance.terminate()
          sleep(DOZE_TIME) until clean_instance.status.eql?(:terminated)
        end

      end # self.agent_ami.nil?
    end # self.active? and self.agent_ami.nil?
  end

  def find_or_create_security_group(group_name = Defaults::SECURITY_GROUP)

    logger.debug { "#{self.class}##{__method__}" }
    vpc = ec2.subnets[self.vpc_subnet_id].vpc if self.vpc_subnet_id
    security_groups = (vpc || ec2).security_groups
    security_group = security_groups.filter('group-name', group_name).first()
    if security_group.nil?
      logger.info("Creating #{group_name} security group on #{self.region}...")
      security_group = security_groups.create(group_name,
                        :description => Defaults::SECURITY_GROUP_DESC, :vpc => vpc)

      security_group.authorize_ingress(:tcp, 22) # allow SSH from anywhere
      # allow incoming TCP to any port within the group
      security_group.authorize_ingress(:tcp, 0..65535, :group_id => security_group.id)
      # allow incoming UDP to any port within the group
      security_group.authorize_ingress(:udp, 0..65535, :group_id => security_group.id)
      # allow ICMP from anywhere
      security_group.allow_ping
    end

    security_group
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
      :logger => logger
    }
  end

  def java_download_url()
    @java_download_url ||= s3_bucket().objects[java_download_file_path()]
                                      .public_url(:secure => false)
  end

  def jmeter_download_url()
    @jmeter_download_url ||= (self.project.custom_jmeter_installer_url || jmeter_s3_object().public_url(:secure => false))
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
    if self.zone.blank? and self.project.master_slave_mode?
      ec2.availability_zones.each do |z|
        if z.state == :available
          self.zone = z.name
          break
        end
      end
    end
  end

  def jmeter_download_file()
    if self.project.custom_jmeter_installer_url.blank?
      "#{jmeter_directory}.tgz"
    else
      self.project.custom_jmeter_installer_file
    end
  end

  # Path relative to S3 bucket
  def jmeter_download_file_path()
    "open-source/#{jmeter_download_file}"
  end

  # Expanded JMeter directory
  def jmeter_directory
    if self.project.custom_jmeter_installer_url.blank?
      version = self.project.jmeter_version
      "#{version == '2.4' ? 'jakarta' : 'apache'}-jmeter-#{version}"
    else
      self.project.custom_jmeter_dir_name
    end
  end

  # Architecture as per instance_type - everything is 64-bit.
  def arch(internal = false)
    internal ? '64-bit' : 'x86_64'
  end

  # The AMI ID to search for and create
  def ami_id()
    # "#{Defaults::AMI_ID}-j#{self.project.jmeter_version}-#{arch()}"
    [Defaults::AMI_ID,
     "j#{self.project.jmeter_version}"].tap { |lst|
      self.project.custom_jmeter_installer_url ? lst.push(self.project.project_code) : lst
    }.push(arch()).join('-')
  end

  # Base AMI to use to create Hailstorm AMI based on the region and instance_type
  # @return [String] Base AMI ID
  def base_ami()
    region_base_ami_map[self.region][arch(true)]
  end

  # Static map of regions, architectures and AMI ID of latest stable Ubuntu LTS AMIs
  # On changes to this map, be sure to execute ``rspec -t integration``.
  def region_base_ami_map()
    @region_base_ami_map ||= {
      'us-east-1' => { # US East (Virginia)
          '64-bit' => 'ami-d05e75b8'
      },
      'us-east-2' => { # US East (Ohio)
          '64-bit' => 'ami-8b92b4ee'
      },
      'us-west-1' => { # US West (N. California)
          '64-bit' => 'ami-df6a8b9b'
      },
      'us-west-2' => { # US West (Oregon)
          '64-bit' => 'ami-5189a661'
      },
      'ca-central-1' => { # Canada (Central)
          '64-bit' => 'ami-b3d965d7'
      },
      'eu-west-1' => {  # EU (Ireland)
          '64-bit' => 'ami-47a23a30'
      },
      'eu-central-1' => {  # EU (Frankfurt)
          '64-bit' => 'ami-accff2b1'
      },
      'eu-west-2' => {  # EU (London)
          '64-bit' => 'ami-cc7066a8'
      },
      'ap-northeast-1' => { # Asia Pacific (Tokyo)
          '64-bit' => 'ami-785c491f'
      },
      'ap-southeast-1' => { # Asia Pacific (Singapore)
          '64-bit' => 'ami-2378f540'
      },
      'ap-southeast-2' => { # Asia Pacific (Sydney)
          '64-bit' => 'ami-e94e5e8a'
      },
      'ap-northeast-2' => { # Asia Pacific (Seoul)
          '64-bit' => 'ami-94d20dfa'
      },
      'ap-south-1' => { # Asia Pacific (Mumbai)
          '64-bit' => 'ami-49e59a26'
      },
      'sa-east-1' => { # South America (Sao Paulo)
          '64-bit' => 'ami-34afc458'
      }
    }
  end

    # @return [String]
    def java_download_file()
    @java_download_file ||= {
        '32-bit' => 'jre-6u31-linux-i586.bin',
        '64-bit' => 'jre-8u144-linux-x64.tar.gz'
    }[arch(true)]
  end

  def java_download_file_path()
    "open-source/#{java_download_file()}"
  end

  def jre_directory()
    @jre_directory ||= {
        '32-bit' => 'jre1.6.0_31',
        '64-bit' => 'jre1.8.0_144'
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

  def default_max_threads_per_agent()
    iclass, itype = self.instance_type.split(/\./).collect { |e| e.to_sym }
    iclass ||= :m3
    itype ||= :medium
    iclass_factor = Defaults::INSTANCE_CLASS_SCALE_FACTOR[iclass] || 1
    itype_factor = Defaults::INSTANCE_TYPE_STEP.call(Defaults::KNOWN_INSTANCE_TYPES.index(itype).to_i + 1)
    self.class.round_off_max_threads_per_agent(iclass_factor * itype_factor * Defaults::MIN_THREADS_ONE_AGENT)
  end

  def self.round_off_max_threads_per_agent(computed)
    pivot = if computed <= 10 then
              5
            else
              computed <= 50 ? 10 : 50
            end
    (computed.to_f / pivot).round() * pivot
  end

  def wait_for_system_checks(ec2_instance, message)
    timeout_message(message) do
      wait_until do
        ec2.client.describe_instance_status(:instance_ids => [ec2_instance.identifier])[:instance_status_set]
        .reduce(true) do |state, e|
          state &&= !e[:system_status][:details].select { |f|
            f[:name] == 'reachability' && f[:status] == 'passed'
          }.empty? && !e[:instance_status][:details].select { |f|
            f[:name] == 'reachability' && f[:status] == 'passed'
          }.empty?
        end
      end
    end
  end

  # @param [String] ami_id
  # @param [Array] security_group_ids
  # @return [AWS::EC2::Instance]
  def create_ec2_instance(ami_id, security_group_ids)
    ec2.instances.create({
         :image_id => ami_id,
         :key_name => self.ssh_identity,
         :security_group_ids => security_group_ids,
         :instance_type => self.instance_type,
         :subnet => self.vpc_subnet_id
    }.tap { |x| x.merge!(:availability_zone => self.zone) if self.zone }
     .tap { |x| x.merge!(:associate_public_ip_address => true) if self.vpc_subnet_id })
  end

  # EC2 default settings
  class Defaults
    AMI_ID              = '3pg-hailstorm'
    SECURITY_GROUP      = 'Hailstorm'
    SECURITY_GROUP_DESC = 'Allows traffic to port 22 from anywhere and internal TCP, UDP and ICMP traffic'
    BUCKET_NAME         = 'brickred-perftest'
    SSH_USER            = 'ubuntu'
    SSH_IDENTITY        = 'hailstorm'
    INSTANCE_TYPE       = 'm3.medium'
    INSTANCE_CLASS_SCALE_FACTOR = {
        t2: 2, m4: 4, m3: 4, c4: 8, c3: 8, r4: 10, r3: 10, d2: 10, i2: 10, i3: 10, x1: 20
    }.freeze
    INSTANCE_TYPE_SCALE_FACTOR = 2
    KNOWN_INSTANCE_TYPES = [:nano, :micro, :small, :medium, :large, :xlarge, '2xlarge'.to_sym, '4xlarge'.to_sym,
                            '10xlarge'.to_sym, '16xlarge'.to_sym, '32xlarge'.to_sym].freeze
    INSTANCE_TYPE_STEP = lambda {|n| a, b, s = 1, 1, 1; (n - 1).times {s = a + b; a = b; b = s }; s}
   MIN_THREADS_ONE_AGENT = 2
  end

end
