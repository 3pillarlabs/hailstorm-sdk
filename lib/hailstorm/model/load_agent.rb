# Model for a load agent. A load agent is a node on which JMeter will execute
# either as a master or as a slave.
# @author Sayantam Dey

require 'hailstorm/model'
require 'hailstorm/support/ssh'
require 'erubis/tiny'

class Hailstorm::Model::LoadAgent < ActiveRecord::Base
  
  belongs_to :clusterable, :polymorphic => true
  
  belongs_to :jmeter_plan
  
  attr_writer :first_use
  
  after_initialize do |agent|
    self.first_use = agent.new_record?
  end
  
  after_commit :upload_scripts, :if => proc {|r| r.active? && !r.public_ip_address.nil?}, :on => :create

  scope :active, -> {where(:active => true)}

  def first_use?
    @first_use
  end

  # This should be defined in the master and slave agent derived classes
  # @abstract
  def start_jmeter()
    raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
  end

  # This should be defined in the master and slave agent derived classes
  def stop_jmeter(wait = false, aborted = false)
    raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
  end

  def jmeter_running?
    not self.jmeter_pid.nil?
  end

  def running?
    not self.public_ip_address.nil?
  end
  
  # Upload the Jmeter scripts, first time the load_agent is created or
  # when the jmeter_plan contents are modified. Pass true for force
  # to upload anyway.
  # @param [Boolean] force defaults to false 
  def upload_scripts(force = false)
    
    if force or self.first_use? or self.jmeter_plan.content_modified?
      logger.info("Uploading script #{self.jmeter_plan.test_plan_name}...")
      directory_hierarchy = nil
      if force or self.first_use?
        directory_hierarchy = self.jmeter_plan.remote_directory_hierarchy()
      end
      test_artifacts = self.jmeter_plan.test_artifacts()

      Hailstorm::Support::SSH.start(self.public_ip_address,
        self.clusterable.user_name, self.clusterable.ssh_options) do |ssh|
        unless directory_hierarchy.nil?
          logger.debug{"Creating directory structure...#{directory_hierarchy.inspect}"}
          create_directory_hierarchy(ssh, self.clusterable.user_home, directory_hierarchy)
        end
        upload_files(ssh, test_artifacts)
      end
      
      self.first_use = false
    end
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
      :jmeter_home => self.clusterable.jmeter_home,
      :user_home => self.clusterable.user_home
    ) # returns evaluated String
  end
  
  def execute_jmeter_command(command)
    
    logger.debug { "#{self.class}##{__method__}" }
    Hailstorm::Support::SSH.start(self.public_ip_address, self.clusterable.user_name,
      self.clusterable.ssh_options) do |ssh|

      logger.debug { command }
      ssh.exec!(command)
      remote_pid = ssh.find_process_id(self.jmeter_plan
                                           .class
                                           .binary_name)
      unless remote_pid.nil?
        self.update_column(:jmeter_pid, remote_pid)
      else
        raise(Hailstorm::Exception, "Could not start jmeter on #{self.identifier}##{self.public_ip_address}. Please report this issue.")
      end
    end
  end
  
#######################  PRIVATE METHODS #################################  
  private
  
  def create_directory_hierarchy(ssh, root_path, hierarchy)
    
    logger.debug { "#{self.class}##{__method__}" }
    hierarchy.each_pair do |dir_key, value|
      dir_path = "#{root_path}/#{dir_key}"
      ssh.make_directory(dir_path)
      unless value.blank?
        create_directory_hierarchy(ssh, dir_path, value)
      end
    end
  end
  
  def upload_files(ssh, test_artifacts)

    logger.debug { "#{self.class}##{__method__}" }
    root_regexp = Regexp.compile("#{Hailstorm.root}#{File::Separator}")
    test_artifacts.each do |local|
      remote = sprintf("%s/%s/%s",
        self.clusterable.user_home, Hailstorm.app_name, local.gsub(root_regexp, ''))
      
      ssh.upload(local, remote)
    end
  end

  
end
