# Defines an interface for an entity that wants to take control of the cluster
# of load agents.
#
# For example, Hailstorm::Model::AmazonCloud includes the Hailstorm::Clusterable
# module and implements the methods in the module.
#
# When adding support for other clusters (like a custom datacenter or Heroku),
# set the Hailstorm::Model::Project#cluster_type to the unqualified class name
# and implement the Hailstorm::Clusterable interface.  
#
# @author Sayantam Dey

require 'hailstorm/behavior'
require 'hailstorm/model/jmeter_plan'
require 'hailstorm/model/slave_agent'
require 'hailstorm/model/master_agent'

module Hailstorm::Behavior::Clusterable
  
 
  # Implement this method to start the agent and update load_agent
  # attributes for persistence.
  # @param [Hailstorm::Model::LoadAgent] load_agent
  # @return [Hash] load agent attributes for persistence
  # @abstract   
  def start_agent(load_agent)
    raise(StandardError, "#{self.class}##{__method__} implementation not found.")
  end
  
  # Implement this method to stop the load agent and update load_agent
  # attributes for persistence.
  # @param [Hailstorm::Model::LoadAgent] load_agent
  # @return [Hash] load agent attributes for persistence
  # @abstract   
  def stop_agent(load_agent)
    raise(StandardError, "#{self.class}##{__method__} implementation not found.")
  end

  # Implement this method to return a description of the clusterable instance
  # @return [String]
  # @abstract
  def slug()
    raise(StandardError, "#{self.class}##{__method__} implementation not found.")
  end

  # Implement to return JSON of attributes to display in a report.
  # @retutn [String] JSON of attributes
  # @abstract
  def public_properties()
    raise(StandardError, "#{self.class}##{__method__} implementation not found.")
  end

  # Implementation should essentially perform all tasks including creating
  # and starting load agents. For example, if Amazon EC2 is used,
  # the implementation should bundle the AMI and start/stop instances as required.
  # @param [Hash] config_attributes configuration attributes specfic to 
  #               Hailstorm::Configuration::ClusterBase derived class attributes and
  #               Hailstorm::Configuration::ClusterBase#active attribute   
  def setup(config_attributes)
    # override and do something appropriate.
  end
  
  # Implement this method to perform additional tasks before starting load generation,
  # default method is empty.
  def before_generate_load()
    # override and do something appropriate.
  end
  
  # Implement this method to perform additional tasks after starting load generation,
  # default method is empty.
  def after_generate_load()
    # override and do something appropriate.
  end
  
  # Implement this method to perform additional tasks before stopping load generation.
  def before_stop_load_generation()
    # override and do something appropriate.
  end
  
  # Implement this method to perform additional tasks after stopping load generation.
  def after_stop_load_generation()
    # override and do something appropriate.
  end
  
  # Implement this method to perform tasks before removing a load agent
  # from the database.
  # @param [Hailstorm::Model::LoadAgent] load_agent
  def before_destroy_load_agent(load_agent)
    # override and do something appropriate.
  end
  
  # Implement this method to perform tasks after removing load agent from the
  # database.
  # @param [Hailstorm::Model::LoadAgent] load_agent
  def after_destroy_load_agent(load_agent)
    # override and do something appropriate.
  end
  
  # Implement this method to return a Hash of options that are processed by
  # Net::SSH. Default is to return an empty Hash.
  # @return [Hash]
  def ssh_options()
    {} # override and do something appropriate.
  end
  
  # Assumes a standard Linux OS where user home is at /home. If the clusterable
  # uses a different OS or setting, override this method.
  # @return [String] user home directory
  def user_home()
    @user_home ||= "/home/#{self.user_name}"
  end
  
  # Assumes Jmeter is installed to user_home at jmeter directory. If the clusterable
  # uses a different location, override this method
  # @return [String] full path to jmeter home (up to but not including bin) on load agents
  def jmeter_home()
    @jmeter_home ||= "#{user_home}/jmeter"
  end
  
  # Callback which gets executed when the module is included in a class or module.
  # The Ruby VM calls this automatically.
  # @param [Class] recipient the class/module which included this module
  def self.included(recipient)
  
    recipient.belongs_to(:project)
  
    recipient.has_many(:load_agents, :as => :clusterable, :dependent => :destroy)
  
    recipient.has_many(:master_agents, :as => :clusterable)
  
    recipient.has_many(:slave_agents, :as => :clusterable)

    recipient.has_many(:client_stats, :as => :clusterable, :dependent => :destroy,
                       :include => :jmeter_plan)

    recipient.after_commit(:provision_agents, :if => proc {|r| r.active?}, :on => :update)
                           
    recipient.after_commit(:disable_agents, :unless => proc {|r| r.active?}, :on => :update)
  end  
  
  # Launch new instances or bring down instances based on number of instances needed
  def provision_agents()
    
    logger.debug { "#{self.class}##{__method__}" }

    self.project.jmeter_plans.where(:active => true).each do |jmeter_plan|

      common_attributes = {
        :jmeter_plan_id => jmeter_plan.id,
        :active => true
      }
      
      required_count = jmeter_plan.required_load_agent_count()
      
      # proc to handle common operations
      provisoner = proc do |relation|
        # count of active agents
        active_count = self.send(relation)
                           .where(common_attributes)
                           .all()
                           .count()
        
        activate_count = required_count - active_count

        activate_count.times do # block wont execute if activate_count <= 0
          # is there an inactive agent? if yes, activate it, or, create new
          agent = self.send(relation)
                      .where(common_attributes.merge(:active => false))
                      .first_or_initialize(:active => true)
          if agent.new_record?
            agent.save!
          else
            agent.update_column(:active, true)
          end
        end
  
        if activate_count < 0
          self.send(relation)
              .where(common_attributes)
              .limit(activate_count.abs)
              .each do |agent|
          
            agent.update_column(:active, false)
          end 
        end
      end 
      
      if self.project.master_slave_mode?
        query = self.master_agents
                    .where(:jmeter_plan_id => jmeter_plan.id)
              
        # abort if more than 1 master agent is present
        if query.all.count > 1
          raise(Hailstorm::Exception,
                "You have switched on master slave mode, please terminate current cycle first")
        end
        
        # one master is necessary
        query.first_or_create!()
             .tap {|agent| agent.update_column(:active, true)}
        
        provisoner.call(:slave_agents) if required_count > 1 
        
      else # not operating in master-slave mode
        # abort if slave agents are present
        slave_agents_count = self.slave_agents
                                 .where(:jmeter_plan_id => jmeter_plan.id)
                                 .all.count()
        if slave_agents_count > 0
          raise(Hailstorm::Exception,
                "You have switched off master slave mode, please terminate current cycle first")
        end
        
        provisoner.call(:master_agents)        
      end
    end
  end
  
  # disable all associated load_agents
  def disable_agents

    logger.debug { "#{self.class}##{__method__}" }
    self.load_agents.each {|agent| agent.update_column(:active, false)}    
  end

  # Start JMeter slaves on load agents
  def start_slave_process()
    
    logger.debug { "#{self.class}##{__method__}" }
    self.slave_agents.where(:active => true).each do |agent|
      Hailstorm::Support::Thread.start(agent) do |a|
        a.upload_scripts(Hailstorm.application.command_processor.redeploy?)
        a.start_jmeter()
      end
    end
    Hailstorm::Support::Thread.join()
  end
  
  # Start JMeter master on load agents
  def start_master_process()
    
    logger.debug { "#{self.class}##{__method__}" }
    self.master_agents.where(:active => true).each do |agent|
      Hailstorm::Support::Thread.start(agent) do |a|
        a.upload_scripts(Hailstorm.application.command_processor.redeploy?)
        a.start_jmeter()  
      end
    end

    Hailstorm::Support::Thread.join()
  end
  
  def stop_master_process()

    logger.debug { "#{self.class}##{__method__}" }
    self.master_agents.where(:active => true).each do |master|
      Hailstorm::Support::Thread.start(master) do |m|
        m.stop_jmeter()
      end
    end

    Hailstorm::Support::Thread.join()
  end

  def destroy_all_agents()
    
    logger.debug { "#{self.class}##{__method__}" }
    self.load_agents.each do |agent|
        Hailstorm::Support::Thread.start(agent) do |a|
          a.destroy()
        end
    end

    Hailstorm::Support::Thread.join()
  end

  # Checks status of JMeter execution on agents and returns array of MasterAgent
  # instances where JMeter is still running. An empty array means JMeter is not
  # running on any agent.
  # @return [Array] of Hailstorm::Model::MasterAgent
  def check_status()

    logger.debug { "#{self.class}##{__method__}" }
    mutex = Mutex.new()
    running_agents = []
    self.master_agents.where(:active => true).each do |master|
      Hailstorm::Support::Thread.start(master) do |m|
        agent = m.check_status()
        unless agent.nil?
          mutex.synchronize { running_agents.push(agent) }
        end
      end
    end

    Hailstorm::Support::Thread.join()

    return running_agents
  end

end
