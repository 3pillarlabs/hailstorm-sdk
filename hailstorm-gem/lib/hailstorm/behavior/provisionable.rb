require 'hailstorm/behavior'

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

  def agent_before_save_on_create(agent)
    start_agent(agent)
  end

  # Calculates the number of agents to be added based on required and current count.
  #
  # @param [ActiveRecord::Relation] query basic relation query that adds common attributes.
  # @param [Fixnum] required_count
  # @yield [ActiveRecord::Relation], [Fixnum] Enumerable for agents that need to be removed, Size of Enumerable
  def agents_to_add(query, required_count, &_block)
    logger.debug { "#{self.class}##{__method__}" }
    active_count = query.count
    activate_count = required_count - active_count
    if block_given?
      activate_count.times do
        yield query, activate_count
      end
    end
    activate_count
  end

  # Calculates the number of agents to be removed based on required and current count.
  #
  # @param [ActiveRecord::Relation] query basic relation query that adds common attributes.
  # @param [Fixnum] required_count
  # @yield [ActiveRecord::Relation] Enumerable for agents that need to be removed.
  def agents_to_remove(query, required_count, &_block)
    logger.debug { "#{self.class}##{__method__}" }
    activate_count = agents_to_add(query, required_count)
    return if activate_count >= 0

    query.limit(activate_count.abs).each { |agent| yield agent }
  end

end
