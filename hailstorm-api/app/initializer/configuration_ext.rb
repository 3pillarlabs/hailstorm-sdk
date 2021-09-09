# frozen_string_literal: true

require 'hailstorm/support/configuration'

class Hailstorm::Support::Configuration
  # JMeter extension
  class JMeter

    def disabled_test_plans
      # For backward compatibility. Existing marshalled representations do not have this field, and unmarshalling
      # does not invoke the constructor.
      @disabled_test_plans ||= []
    end

    attr_writer :disabled_test_plans

    alias original_initialize initialize
    def initialize
      original_initialize
      self.disabled_test_plans = []
    end

    # @return [Array<Hash>] hash hash.keys = [:test_plan_name, :jmx_file, :disabled]
    #                            test_plan_name: String
    #                            jmx_file: Boolean, true
    #                            disabled: Boolean
    def all_test_plans_attrs
      return [] if self.test_plans.nil?

      self.test_plans.map do |plan|
        attrs = { test_plan_name: plan, jmx_file: true }
        attrs[:disabled] = true if self.disabled_test_plans.include?(plan)
        attrs
      end
    end

    # All test plans that are not disabled. Does not include data files
    # @return [Array<String>]
    def enabled_test_plans
      return [] if self.test_plans.blank?

      self.test_plans.reject { |plan| self.disabled_test_plans.include?(plan) }
    end
  end
end
