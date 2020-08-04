require 'hailstorm/model/helper'
require 'hailstorm/behavior/loggable'
require 'hailstorm/model/helper/ami_provision_helper'
require 'hailstorm/support/waiter'

# Helper to create AMI
class Hailstorm::Model::Helper::AmiHelper
  include Hailstorm::Behavior::Loggable
  include Hailstorm::Support::Waiter

  attr_reader :aws_clusterable, :security_group_finder, :ec2_instance_helper, :instance_client, :ami_client

  # @param [Hailstorm::Model::AmazonCloud] aws_clusterable
  # @param [Hailstorm::Model::Helper::SecurityGroupFinder] security_group_finder
  # @param [Hailstorm::Model::Helper::Ec2InstanceHelper] ec2_instance_helper
  # @param [Hailstorm::Behavior::AwsAdaptable::InstanceClient] instance_client
  # @param [Hailstorm::Behavior::AwsAdaptable::AmiClient] ami_client
  def initialize(aws_clusterable:, security_group_finder:, ec2_instance_helper:, instance_client:, ami_client:)
    @aws_clusterable = aws_clusterable
    @security_group_finder = security_group_finder
    @ec2_instance_helper = ec2_instance_helper
    @instance_client = instance_client
    @ami_client = ami_client
  end

  # creates the agent ami and updates `aws_clusterable#agent_ami`
  def create_agent_ami!
    return unless ami_creation_needed?

    # AMI does not exist
    logger.info("Creating agent AMI for #{aws_clusterable.region}...")
    security_group = security_group_finder.find_security_group
    clean_instance = nil
    begin
      clean_instance = ec2_instance_helper.create_ec2_instance(ami_id: base_ami,
                                                               security_group_ids: security_group.id)
      build_ami(clean_instance)
    rescue Exception => ex
      logger.error(
        "Failed to create instance on #{aws_clusterable.region}: #{ex.message}, terminating temporary instance..."
      )
      raise(ex)
    ensure
      terminate_instance(clean_instance) if clean_instance
    end
  end

  # Static map of regions, architectures and AMI ID of latest stable Ubuntu LTS AMIs
  # On changes to this map, be sure to execute ``rspec -t integration``.
  ARCH_64 = '64-bit'.freeze

  def self.region_base_ami_map
    @region_base_ami_map ||= [
      { region: 'us-east-1',      ami: 'ami-07ebfd5b3428b6f4d' }, # US East (Virginia)
      { region: 'us-east-2',      ami: 'ami-0fc20dd1da406780b' }, # US East (Ohio)
      { region: 'us-west-1',      ami: 'ami-03ba3948f6c37a4b0' }, # US West (N. California)
      { region: 'us-west-2', 	    ami: 'ami-0d1cd67c26f5fca19' }, # US West (Oregon)
      { region: 'ca-central-1',   ami: 'ami-0d0eaed20348a3389' }, # Canada (Central)
      { region: 'eu-west-1',      ami: 'ami-035966e8adab4aaad' }, # EU (Ireland)
      { region: 'eu-central-1',   ami: 'ami-0b418580298265d5c' }, # EU (Frankfurt)
      { region: 'eu-west-2',      ami: 'ami-006a0174c6c25ac06' }, # EU (London)
      { region: 'ap-northeast-1', ami: 'ami-07f4cb4629342979c' }, # Asia Pacific (Tokyo)
      { region: 'ap-southeast-1', ami: 'ami-09a4a9ce71ff3f20b' }, # Asia Pacific (Singapore)
      { region: 'ap-southeast-2', ami: 'ami-02a599eb01e3b3c5b' }, # Asia Pacific (Sydney)
      { region: 'ap-northeast-2', ami: 'ami-0cd7b0de75f5a35d1' }, # Asia Pacific (Seoul)
      { region: 'ap-south-1',     ami: 'ami-0620d12a9cf777c87' }, # Asia Pacific (Mumbai)
      { region: 'sa-east-1',      ami: 'ami-05494b93950efa2fd' }  # South America (Sao Paulo)
    ].reduce({}) { |s, e| s.merge(e[:region] => { ARCH_64 => e[:ami] }) }
  end

  private

  def terminate_instance(instance)
    instance_client.terminate(instance_id: instance.id)
    logger.debug { "status: #{instance.status}" }
    wait_for("Instance #{instance.id} to terminate",
             err_attrs: { region: aws_clusterable.region }) { instance_client.terminated?(instance_id: instance.id) }
  end

  # @return [Boolean] true if agent AMI should be created
  def ami_creation_needed?
    aws_clusterable.active? && aws_clusterable.agent_ami.nil? && check_for_existing_ami.nil?
  end

  # Check if this region already has the Hailstorm AMI and return the identifier.
  # @return [String] AMI id
  def check_for_existing_ami
    regexp = Regexp.compile(ami_id)
    logger.info("Searching available AMI on #{aws_clusterable.region}...")
    ex_ami = ami_client.find_self_owned(ami_name_regexp: regexp)
    if ex_ami
      aws_clusterable.agent_ami = ex_ami.id
      logger.info("Using AMI #{aws_clusterable.agent_ami} for #{aws_clusterable.region}...")
    end

    ex_ami
  end

  # Build the AMI from a running instance
  def build_ami(instance)
    provision(instance)
    logger.info { "Finalizing changes for #{aws_clusterable.region} AMI..." }
    aws_clusterable.agent_ami = register_hailstorm_ami(instance)
    logger.info("New AMI##{aws_clusterable.agent_ami} / #{aws_clusterable.region} created successfully, cleaning up...")
  end

  # Install everything
  def provision(instance)
    custom_jmeter_installer_url = aws_clusterable.project.custom_jmeter_installer_url
    jmeter_version = aws_clusterable.project.jmeter_version
    provision_helper = Hailstorm::Model::Helper::AmiProvisionHelper.new(region: aws_clusterable.region,
                                                                        jmeter_version: jmeter_version,
                                                                        user_home: aws_clusterable.user_home,
                                                                        download_url: custom_jmeter_installer_url)

    Hailstorm::Support::SSH.start(instance.public_ip_address,
                                  aws_clusterable.user_name,
                                  aws_clusterable.ssh_options) do |ssh|
      provision_helper.install_java(ssh)
      provision_helper.install_jmeter(ssh)
    end
  end

  # Create and register the AMI
  # @param [Hailstorm::Behavior::AwsAdaptable::Instance] instance
  # @return [String] AMI Id of the just registered AMI
  def register_hailstorm_ami(instance)
    new_ami_id = ami_client.register_ami(
      name: ami_id,
      instance_id: instance.instance_id,
      description: 'AMI for distributed performance testing with Hailstorm'
    )

    begin
      wait_for("Hailstorm AMI #{ami_id} on #{aws_clusterable.region} to be created") do
        ami_client.available?(ami_id: new_ami_id)
      end
    rescue Hailstorm::Exception
      ami = ami_client.find(ami_id: new_ami_id)
      raise(Hailstorm::AmiCreationFailure.new(aws_clusterable.region, ami.state_reason))
    end

    new_ami_id
  end

  # Architecture as per instance_type - everything is 64-bit.
  def arch(internal = false)
    internal ? '64-bit' : 'x86_64'
  end

  # The AMI ID to search for and create
  def ami_id
    [aws_clusterable.ami_prefix,
     "j#{aws_clusterable.project.jmeter_version}"]
      .push(aws_clusterable.project.custom_jmeter_installer_url ? aws_clusterable.project.project_code : nil)
      .push(arch)
      .push(Hailstorm.production? ? nil : Hailstorm.env)
      .compact
      .join('-')
  end

  # Base AMI to use to create Hailstorm AMI based on the region and instance_type
  # @return [String] Base AMI ID
  def base_ami
    self.class.region_base_ami_map[aws_clusterable.region][arch(true)]
  end
end
