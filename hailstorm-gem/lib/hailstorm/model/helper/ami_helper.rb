# frozen_string_literal: true

require 'hailstorm/model/helper'
require 'hailstorm/behavior/loggable'
require 'hailstorm/model/helper/ami_provision_helper'
require 'hailstorm/support/waiter'
require 'hailstorm/model/helper/aws_region_helper'

# Helper to create AMI. Use the Builder to create an instance.
class Hailstorm::Model::Helper::AmiHelper
  include Hailstorm::Behavior::Loggable
  include Hailstorm::Support::Waiter

  # Group of helpers
  class MemberHelperGroup
    attr_reader :security_group_finder, :ec2_instance_helper, :aws_region_helper

    # @param [Hailstorm::Model::Helper::SecurityGroupFinder] security_group_finder
    # @param [Hailstorm::Model::Helper::Ec2InstanceHelper] ec2_instance_helper
    # @param [Hailstorm::Model::Helper::AwsRegionHelper] aws_region_helper
    def initialize(security_group_finder:,
                   ec2_instance_helper:,
                   aws_region_helper: Hailstorm::Model::Helper::AwsRegionHelper.new)
      @security_group_finder = security_group_finder
      @ec2_instance_helper = ec2_instance_helper
      @aws_region_helper = aws_region_helper
    end
  end

  # Group of clients
  class ClientGroup
    attr_reader :instance_client, :ami_client

    # @param [Hailstorm::Behavior::AwsAdaptable::InstanceClient] instance_client
    # @param [Hailstorm::Behavior::AwsAdaptable::AmiClient] ami_client
    def initialize(instance_client:,
                   ami_client:)
      @instance_client = instance_client
      @ami_client = ami_client
    end
  end

  attr_reader :aws_clusterable,
              :security_group_finder,
              :ec2_instance_helper,
              :instance_client,
              :ami_client,
              :aws_region_helper

  # @param [Hailstorm::Model::AmazonCloud] aws_clusterable
  # @param [Hailstorm::Model::Helper::AmiHelper::MemberHelperGroup] helper_group
  # @param [Hailstorm::Model::Helper::AmiHelper::ClientGroup] client_group
  def initialize(aws_clusterable:, helper_group:, client_group:)
    @aws_clusterable = aws_clusterable
    @security_group_finder = helper_group.security_group_finder
    @ec2_instance_helper = helper_group.ec2_instance_helper
    @instance_client = client_group.instance_client
    @ami_client = client_group.ami_client
    @aws_region_helper = helper_group.aws_region_helper
  end

  # creates the agent ami and updates `aws_clusterable#agent_ami`
  def create_agent_ami!
    return unless ami_creation_needed?

    # AMI does not exist
    logger.info("Creating agent AMI for #{aws_clusterable.region}...")
    security_group = security_group_finder.find_security_group
    clean_instance = nil
    begin
      clean_instance = ec2_instance_helper.create_ec2_instance(ami_id: lookup_base_ami,
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

  def region_base_ami_map
    aws_region_helper.region_base_ami_map
  end

  private

  def terminate_instance(instance)
    instance_client.terminate(instance_id: instance.id)
    logger.debug { "status: #{instance.status}" }
    wait_for("Instance #{instance.id} to terminate",
             err_attrs: { region: aws_clusterable.region }) { instance_client.terminated?(instance_id: instance.id) }
  rescue StandardError => error
    logger.warn(error.message)
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
    rescue Hailstorm::Exception => error
      ami = ami_client.find(ami_id: new_ami_id)
      ami_error = Hailstorm::AmiCreationFailure.new(aws_clusterable.region, ami.state_reason)
      ami_error.retryable = error.retryable?
      raise(ami_error)
    end

    new_ami_id
  end

  AMI_ARCH = 'x86_64'

  # The AMI ID to search for and create
  def ami_id
    [aws_clusterable.ami_prefix,
     "j#{aws_clusterable.project.jmeter_version}"]
      .push(aws_clusterable.project.custom_jmeter_installer_url ? aws_clusterable.project.project_code : nil)
      .push(AMI_ARCH)
      .push(Hailstorm.production? ? nil : Hailstorm.env)
      .compact
      .join('-')
  end

  # Base AMI to use to create Hailstorm AMI based on the region
  # @return [String] Base AMI ID
  def lookup_base_ami
    base_ami = region_base_ami_map[aws_clusterable.region]
    return base_ami unless base_ami.nil?

    base_ami = aws_clusterable.base_ami
    if base_ami.nil?
      raise(Hailstorm::Exception, "No base_ami specified for unsupported region #{aws_clusterable.region}")
    end

    unless ami_client.available?(ami_id: base_ami)
      raise(Hailstorm::Exception,
            "AMI #{base_ami} not available in AWS region #{aws_clusterable.region}")
    end

    base_ami
  end
end
