# frozen_string_literal: true

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

  # :nocov:
  # This should be defined in the master and slave agent derived classes
  # @abstract
  def start_jmeter
    raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
  end

  # This should be defined in the master and slave agent derived classes
  def stop_jmeter(wait: false, aborted: false)
    raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
  end

  # A load agent is neither a "slave" nor a "master"
  def slave?
    false
  end

  # A load agent is neither a "slave" nor a "master"
  def master?
    false
  end

  # :nocov:

  def first_use?
    @first_use
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
  def upload_scripts(force: false)
    return unless script_upload_needed?(force: force)

    logger.info("Uploading script #{self.jmeter_plan.test_plan_name}...")
    Hailstorm::Support::SSH.start(*ssh_start_args) do |ssh|
      remote_sync(ssh, force: force)
    end
    self.first_use = false
  end

  #######################  PROTECTED METHODS #################################

  protected

  def evaluate_execute(command_template)
    return if command_template.nil?

    logger.debug(command_template)
    command = evaluate_command(command_template)
    logger.debug(command)
    execute_jmeter_command(command)
  end

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

  # wait for graceful shutdown
  def wait_for_shutdown(ssh, doze_time, max_tries = 3)
    tries = 0
    until tries >= max_tries
      sleep(doze_time)
      break unless ssh.process_running?(self.jmeter_pid)

      tries += 1
    end

    return if tries < max_tries

    # graceful shutdown is not happening
    ssh.terminate_process_tree(self.jmeter_pid)
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
    code = self.clusterable.project.project_code
    root_regexp = Regexp.compile("#{Hailstorm.workspace(code).workspace_path}#{File::Separator}")
    test_artifacts.each do |local|
      remote = format('%<home>s/%<app>s/%<path>s',
                      home: self.clusterable.user_home,
                      app: code,
                      path: local.gsub(root_regexp, ''))

      ssh.upload(local, remote)
    end
  end

  def script_upload_needed?(force: false)
    first_use_or_refresh?(force: force) || self.jmeter_plan.content_modified?
  end

  def first_use_or_refresh?(force: false)
    force || self.first_use?
  end

  def ssh_start_args
    [self.public_ip_address, self.clusterable.user_name, self.clusterable.ssh_options]
  end

  def remote_sync(ssh, force: false)
    directory_hierarchy = self.jmeter_plan.remote_directory_hierarchy if first_use_or_refresh?(force: force)
    if directory_hierarchy
      logger.debug { "Creating directory structure...#{directory_hierarchy.inspect}" }
      create_directory_hierarchy(ssh, self.clusterable.user_home, directory_hierarchy)
    end
    upload_files(ssh, self.jmeter_plan.test_artifacts)
  end
end
