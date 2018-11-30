require 'spec_helper'
require 'hailstorm/model/jmeter_plan'
require 'jmeter_plan_spec_overrides'

describe Hailstorm::Model::JmeterPlan do

  before(:each) do
    @jmeter_plan = Hailstorm::Model::JmeterPlan.new
    @jmeter_plan.test_plan_name = 'hailstorm-site-basic'
    @jmeter_plan.extend(JmeterPlanSpecOverrides)
    @jmeter_plan.validate_plan = true
    @jmeter_plan.active = true
  end

  context 'when all properties in plan are defined in the model properties' do
    it 'should be valid' do
      @jmeter_plan.properties_map = { NumUsers: 10, Duration: 180, ServerName: 'foo.com', RampUp: 0, StartupDelay: 0 }.stringify_keys
      expect(@jmeter_plan).to be_valid
    end
  end

  context 'when any property in plan is not defined in the model properties' do
    it 'should not be valid' do
      @jmeter_plan.properties_map = { Duration: 180, ServerName: 'foo.com', RampUp: 0, StartupDelay: 0 }.stringify_keys
      expect(@jmeter_plan).to_not be_valid
    end
  end

  context 'when a property with default value in plan is not defined in the model properties' do
    it 'should be valid' do
      @jmeter_plan.properties_map = { NumUsers: 10, Duration: 180, ServerName: 'foo.com' }.stringify_keys
      expect(@jmeter_plan).to be_valid
    end
  end

  context 'when property with default value is defined in model properties as well' do
    it 'the value from model properties takes precedence' do
      @jmeter_plan.properties_map = { NumUsers: 10, Duration: 180, ServerName: 'foo.com', RampUp: 10 }.stringify_keys
      @jmeter_plan.send(:extracted_property_names)
      expect(@jmeter_plan.properties_map['RampUp']).to eq(10)
    end
  end

end
