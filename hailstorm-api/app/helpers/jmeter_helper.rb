module JMeterHelper

  # Predicate that returns true if the argument is a JMeter test plan
  # @param [String] test_plan_name
  def jmx_file?(test_plan_name)
    /\.jmx$/.match(test_plan_name)
  end

  def to_jmeter_attributes(hailstorm_config, project_id, partial_attrs, index)
    obj = {}
    obj[:id] = "#{project_id}#{index + 1}"
    obj[:projectId] = project_id
    obj[:path] = File.dirname(partial_attrs[:test_plan_name])
    if partial_attrs[:jmx_file]
      obj[:name] = "#{File.basename(partial_attrs[:test_plan_name])}.jmx"
      properties = hailstorm_config.jmeter.properties(test_plan: partial_attrs[:test_plan_name])
      obj[:properties] = properties.entries
    else
      obj[:name] = File.basename(partial_attrs[:test_plan_name])
      obj[:dataFile] = true
    end

    obj
  end

  def update_map(map, data)
    data['properties'].each { |name, value| map[name] = value }
  end
end
