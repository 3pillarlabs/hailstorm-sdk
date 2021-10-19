# frozen_string_literal: true

require 'hailstorm/model/concern'

# Method implementation of `Clusterable` interface
module Hailstorm::Model::Concern::AbstractClusterable

  # Creates an load agent AMI with all required packages pre-installed and
  # starts requisite number of instances
  def setup(force: false)
    logger.debug { "#{self.class}##{__method__}" }
    self.save! if self.changed? || self.new_record?
    return unless self.active? || force

    provision_agents
  end
end
