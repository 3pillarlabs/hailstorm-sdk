# Mixin to be included for JMeter tests
module JmeterPlanSpecOverrides
  def test_plan_file_path
    File.expand_path("../../features/data/#{self.test_plan_name}.jmx", __FILE__)
  end

  attr_writer :properties_map
end
