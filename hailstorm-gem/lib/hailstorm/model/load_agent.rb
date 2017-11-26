require 'hailstorm/model'
require 'hailstorm/support/ssh'
require 'erubis/tiny'

# Model for a load agent. A load agent is a node on which JMeter will execute
# either as a master or as a slave.
# @author Sayantam Dey
class Hailstorm::Model::LoadAgent < ActiveRecord::Base
  belongs_to :clusterable, polymorphic: true

  belongs_to :jmeter_plan

  after_initialize do |agent|
    self.first_use = agent.new_record?
  end

  after_commit :upload_scripts, if: proc { |r| r.active? && !r.public_ip_address.nil? }, on: :create

  scope :active, -> { where(active: true) }

  attr_writer :first_use

  def first_use?
    @first_use
  end

  # This should be defined in the master and slave agent derived classes
  # @abstract
  def start_jmeter
    raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
  end

  # This should be defined in the master and slave agent derived classes
  def stop_jmeter(_wait = false, _aborted = false)
    raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
  end

  def jmeter_running?
    !self.jmeter_pid.nil?
  end

  def running?
    !self.public_ip_address.nil?
  end

  # Upload the Jmeter scripts, first time the load_agent is created or
  # when the jmeter_plan contents are modified. Pass true for force
  # to upload anyway.
  # @param [Boolean] force defaults to false
  def upload_scripts(force = false)
    return unless script_upload_needed?(force)
    logger.info("Uploading script #{self.jmeter_plan.test_plan_name}...")
    Hailstorm::Support::SSH.start(*ssh_start_args) do |ssh|
      remote_sync(ssh, force)
    end
    self.first_use = false
  end

  # A load agent is neither a "slave" nor a "master"
  def slave?
    false
  end

  # A load agent is neither a "slave" nor a "master"
  def master?
    false
  end

  #######################  PROTECTED METHODS #################################

  protected

  # Evaluate command assuming command is an erubis template
  def evaluate_command(command_template)
    logger.debug { "#{self.class}##{__method__}" }
    eruby = Erubis::TinyEruby.new(command_template)
    eruby.evaluate(
      jmeter_home: self.clusterable.jmeter_home,
      user_home: self.clusterable.user_home
    ) # returns evaluated String
  end

  def execute_jmeter_command(command)
    logger.debug { command }
    Hailstorm::Support::SSH.start(*ssh_start_args) do |ssh|
      ssh.exec!(command)
      remote_pid = ssh.find_process_id(self.jmeter_plan.class.binary_name)
      if remote_pid
        self.update_column(:jmeter_pid, remote_pid)
        break
      end
      raise(Hailstorm::Exception, "Failed to start jmeter on #{self.identifier}##{self.public_ip_address}.")
    end
  end

  #######################  PRIVATE METHODS #################################
  private

  def create_directory_hierarchy(ssh, root_path, hierarchy)
    logger.debug { "#{self.class}##{__method__}" }
    hierarchy.each_pair do |dir_key, value|
      dir_path = "#{root_path}/#{dir_key}"
      ssh.make_directory(dir_path)
      create_directory_hierarchy(ssh, dir_path, value) unless value.blank?
    end
  end

  def upload_files(ssh, test_artifacts)
    logger.debug { "#{self.class}##{__method__}" }
    root_regexp = Regexp.compile("#{Hailstorm.root}#{File::Separator}")
    test_artifacts.each do |local|
      remote = format('%s/%s/%s',
                      self.clusterable.user_home, Hailstorm.app_name, local.gsub(root_regexp, ''))

      ssh.upload(local, remote)
    end
  end

  def script_upload_needed?(force = false)
    first_use_or_refresh?(force) || self.jmeter_plan.content_modified?
  end

  def first_use_or_refresh?(force = false)
    force || self.first_use?
  end

  def ssh_start_args
    [self.public_ip_address, self.clusterable.user_name, self.clusterable.ssh_options]
  end

  def remote_sync(ssh, force = false)
    directory_hierarchy = self.jmeter_plan.remote_directory_hierarchy if first_use_or_refresh?(force)
    if directory_hierarchy
      logger.debug { "Creating directory structure...#{directory_hierarchy.inspect}" }
      create_directory_hierarchy(ssh, self.clusterable.user_home, directory_hierarchy)
    end
    upload_files(ssh, self.jmeter_plan.test_artifacts)
  end
end
