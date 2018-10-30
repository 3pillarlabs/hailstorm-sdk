require 'hailstorm/behavior'
require 'hailstorm/behavior/clusterable'

# Interface for clusters that are able to provision resources
module Hailstorm::Behavior::Provisionable

  # :nocov:

  # Implement this method to start the agent and update load_agent
  # attributes for persistence.
  # @param [Hailstorm::Model::LoadAgent] _load_agent
  # @return [Hash] load agent attributes for persistence
  # @abstract
  def start_agent(_load_agent)
    raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
  end

  # Implement this method to stop the load agent and update load_agent
  # attributes for persistence.
  # @param [Hailstorm::Model::LoadAgent] _load_agent
  # @return [Hash] load agent attributes for persistence
  # @abstract
  def stop_agent(_load_agent)
    raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
  end

  # Implement to get load agent count for each cluster type
  # @param [Hailstorm::Model::JmeterPlan] _jmeter_plan
  # @return [Int] count of required load agents to run the test
  # @abstract
  def required_load_agent_count(_jmeter_plan)
    raise(NotImplementedError, "#{self.class}##{__method__} implementation not found.")
  end

  # Implement this method to perform tasks before removing a load agent
  # from the database.
  # @param [Hailstorm::Model::LoadAgent] _load_agent
  def before_destroy_load_agent(_load_agent)
    # override and do something appropriate.
  end

  # Implement this method to perform tasks after removing load agent from the
  # database.
  # @param [Hailstorm::Model::LoadAgent] _load_agent
  def after_destroy_load_agent(_load_agent)
    # override and do something appropriate.
  end

  # :nocov:

end
