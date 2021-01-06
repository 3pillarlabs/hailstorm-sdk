# frozen_string_literal: true

require 'hailstorm/behavior'
require 'hailstorm/model/jmeter_plan'
require 'hailstorm/model/slave_agent'
require 'hailstorm/model/master_agent'
require 'hailstorm/support/collection_helper'
require 'hailstorm/exceptions'

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
module Hailstorm::Behavior::Clusterable

  include Hailstorm::Support::CollectionHelper

  # Helper methods for JMeter
  module JMeterHelper

    # Assumes Jmeter is installed to user_home at jmeter directory. If the clusterable
    # uses a different location, override this method
    # @return [String] full path to jmeter home (up to but not including bin) on load agents
    def jmeter_home
      @jmeter_home ||= "#{user_home}/jmeter"
    end

    # Start JMeter slaves on load agents
    def start_slave_process(redeploy: false)
      logger.debug { "#{self.class}##{__method__}" }
      start_jmeter_process(self.slave_agents.where(active: true), redeploy)
    end

    # Start JMeter master on load agents
    def start_master_process(redeploy: false)
      logger.debug { "#{self.class}##{__method__}" }
      start_jmeter_process(self.master_agents.where(active: true), redeploy)
    end

    def start_jmeter_process(iterable, redeploy)
      visit_collection(iterable) do |agent|
        agent.upload_scripts(force: redeploy)
        agent.start_jmeter
      end
    end

    # Stop JMeter master process on load agents
    def stop_master_process(wait: false, aborted: false)
      logger.debug { "#{self.class}##{__method__}" }
      visit_collection(self.master_agents.where(active: true).all) do |master|
        master.stop_jmeter(wait: wait, aborted: aborted)
      end
    end

    # Processes each plan to launch new agents, enable them or disable them based on required count
    # @param [Hailstorm::Model::JMeterPlan] jmeter_plan
    #
    # @return [Array<Hailstorm::Model::LoadAgent>] activated agents
    def process_jmeter_plan(jmeter_plan)
      logger.debug { "#{self.class}##{__method__}(#{jmeter_plan})" }
      begin
        create_or_enable({ jmeter_plan_id: jmeter_plan.id, active: true },
                         jmeter_plan,
                         master_slave_relation(jmeter_plan))
      rescue Exception => e
        raise(e) if e.is_a?(Hailstorm::Exception)

        logger.error(e.message)
        logger.debug { e.backtrace.prepend("\n").join("\n") }
        raise(Hailstorm::AgentCreationFailure)
      end
    end

    def master_slave_relation(jmeter_plan)
      if self.project.master_slave_mode?
        query = self.master_agents
                    .where(jmeter_plan_id: jmeter_plan.id)

        # abort if more than 1 master agent is present
        raise(Hailstorm::MasterSlaveSwitchOnConflict) if query.all.count > 1

        # one master is necessary
        query.first_or_create!.tap { |agent| agent.update_column(:active, true) }
        :slave_agents

      else # not operating in master-slave mode
        # abort if slave agents are present
        slave_agents_count = self.slave_agents
                                 .where(jmeter_plan_id: jmeter_plan.id)
                                 .all.count
        raise(Hailstorm::MasterSlaveSwitchOffConflict) if slave_agents_count.positive?

        :master_agents
      end
    end

    # Creates master/slave agents based on the relation.
    #
    # @param [Hash] attributes
    # @param [Hailstorm::Model::JmeterPlan] jmeter_plan
    # @param [ActiveRecord::Relation] relation
    # @return [Array<Hailstorm::Model::LoadAgent>] active agents
    def create_or_enable(attributes, jmeter_plan, relation)
      logger.debug { "#{self.class}##{__method__}(#{[attributes, relation]})" }
      activated_agents = []
      mutex = Mutex.new

      query = self.send(relation).where(attributes)
      required_count = required_load_agent_count(jmeter_plan)
      activate_count = agents_to_add(query, required_count) do |q, count|
        # is there an inactive agent? if yes, activate it, or, create new
        activate_agent(activated_agents, count, mutex, q)
      end

      Hailstorm::Support::Thread.join if activate_count > 1 # wait for agents to be created

      agents_to_remove(query, required_count) { |agent| agent.update_column(:active, false) }
      activated_agents
    end

    def activate_agent(activated_agents, count, mutex, query)
      agent = query.unscope(where: :active).where(active: false).first_or_initialize { |r| r.active = true }
      if agent.new_record?
        create_new_agent(activated_agents, agent, count, mutex) do |initialized_agent|
          agent_before_save_on_create(initialized_agent)
        end
      else
        agent.update_column(:active, true)
      end
    end

    # creates a new agent
    # @param [Array<Hailstorm::Model::LoadAgent>] activated_agents array of agents to add agent to
    # @param [Hailstorm::Model::LoadAgent] agent load agent to be created
    # @param [Fixnum] count #agents that will be created
    # @param [Mutex] mutex Mutex to synchronize addition of agents to activated_agents
    def create_new_agent(activated_agents, agent, count, mutex)
      if count > 1
        Hailstorm::Support::Thread.start(agent) do |agent_instance|
          yield agent_instance if block_given?
          agent_instance.save!
          mutex.synchronize { activated_agents.push(agent_instance) }
        end
      else
        yield agent if block_given?
        agent.save!
        activated_agents.push(agent)
      end
    end
  end

  # Helper methods for load agents
  module LoadAgentHelper

    # :nocov:

    # @param [Hailstorm::Model::JmeterPlan] _jmeter_plan
    # @return [Fixnum] number of agents to needed as per threads in JMeter plan
    def required_load_agent_count(_jmeter_plan)
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end

    # Yields each agent and total number of agents to be added for load generation.
    #
    # @param [ActiveRecord::Relation] _query
    # @param [Fixnum] _required_count
    # @param [Block] _block
    def agents_to_add(_query, _required_count, &_block)
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end

    # Yields each agent to be removed from load generation.
    #
    # @param [ActiveRecord::Relation] _query
    # @param [Fixnum] _required_count
    # @param [Block] _block
    def agents_to_remove(_query, _required_count, &_block)
      raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
    end

    # Implement this method to perform checks on the load agent before it is persisted.
    # @param [Hailstorm::Model::LoadAgent] _load_agent
    # @raise [Hailstorm::Exception]
    def agent_before_save_on_create(_load_agent)
      # override and perform checks, raise Hailstorm::Exception or sub-class in case of failed checks.
    end

    # Implement this method to perform additional tasks before starting load generation,
    # default method is empty.
    def before_generate_load
      # override and do something appropriate.
    end

    # Implement this method to perform additional tasks after starting load generation,
    # default method is empty.
    def after_generate_load
      # override and do something appropriate.
    end

    # Implement this method to perform additional tasks before stopping load generation.
    def before_stop_load_generation
      # override and do something appropriate.
    end

    # Implement this method to perform additional tasks after stopping load generation.
    # @param [Hash] _options
    def after_stop_load_generation(_options = nil)
      # override and do something appropriate.
    end

    # :nocov:

    def destroy_all_agents(&block)
      logger.debug { "#{self.class}##{__method__}" }
      visit_collection(self.load_agents.all, &block)
    end
  end

  include LoadAgentHelper
  include JMeterHelper

  # :nocov:

  # Implement this method to return a description of the clusterable instance
  # @return [String]
  # @abstract
  def slug
    raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
  end

  # Implement to return JSON of attributes to display in a report.
  # @return [Hash] attributes
  # @abstract
  def public_properties
    raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
  end

  # Implementation should essentially perform validation, persistence and state
  # management tasks. This method may be called on a new or existing instance,
  # the implementation will have to check and take appropriate actions.
  # @param [Boolean] force Implementation may redo actions even if already done.
  def setup(force: false)
    raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
  end

  # Implement this method to perform house keeping activities after
  # all load agents have been destroyed. This method is call right after the
  # call to <tt>destory_all_agents()</tt> method.
  def cleanup
    # override and do something appropriate.
  end

  # Implement this method to provide a way to completely remove all resources that
  # may have been created by the cluster implementation.
  def purge(*_args)
    # override and do something appropriate
  end

  # :nocov:

  # Assumes a standard Linux OS where user home is at /home or /root for root. If the clusterable
  # uses a different OS or setting, override this method.
  # @return [String] user home directory
  def user_home
    @user_home ||= self.user_name.to_s.to_sym != :root ? "/home/#{self.user_name}" : '/root'
  end

  # Callback which gets executed when the module is included in a class or module.
  # The Ruby VM calls this automatically.
  # @param [Class] recipient the class/module which included this module
  def self.included(recipient)
    recipient.belongs_to(:project)

    recipient.has_many(:load_agents, as: :clusterable, dependent: :destroy)

    recipient.has_many(:master_agents, as: :clusterable)

    recipient.has_many(:slave_agents, as: :clusterable)

    recipient.has_many(:client_stats, as: :clusterable, dependent: :destroy)

    recipient.after_update(:disable_agents, unless: ->(r) { r.active? })
  end

  # Launch new instances or bring down instances based on number of instances needed
  # @return [Array<Hailstorm::Model::LoadAgent>]  activated agents
  def provision_agents
    return if self.destroyed?

    logger.debug { "#{self.class}##{__method__}" }
    self.project.jmeter_plans.where(active: true).all.collect { |jmeter_plan| process_jmeter_plan(jmeter_plan) }.flatten
  end

  # Checks status of JMeter execution on agents and returns array of MasterAgent
  # instances where JMeter is still running. An empty array means JMeter is not
  # running on any agent.
  # @return [Array] of Hailstorm::Model::MasterAgent
  def check_status
    logger.debug { "#{self.class}##{__method__}" }
    mutex = Mutex.new
    running_agents = []
    visit_collection(self.master_agents.where(active: true).all) do |master|
      agent = master.check_status
      mutex.synchronize { running_agents.push(agent) } unless agent.nil?
    end

    running_agents
  end

  private

  # disable all associated load_agents
  def disable_agents
    return if self.destroyed?

    logger.debug { "#{self.class}##{__method__}" }
    self.load_agents.each { |agent| agent.update_column(:active, false) }
  end
end
