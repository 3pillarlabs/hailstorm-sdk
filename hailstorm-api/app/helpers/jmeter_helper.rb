module JMeterHelper

  # Predicate that returns true if the argument is a JMeter test plan
  # @param [String] test_plan_name
  def jmx_file?(test_plan_name)
    /\.jmx$/.match(test_plan_name)
  end

  def to_jmeter_attributes(hailstorm_config, project_id, partial_attrs)
    obj = {}
    obj[:projectId] = project_id
    obj[:path] = File.dirname(partial_attrs[:test_plan_name])
    if partial_attrs[:jmx_file]
      obj[:id] = File.strip_ext(partial_attrs[:test_plan_name]).to_java_string.hash_code
      obj[:name] = "#{File.basename(partial_attrs[:test_plan_name])}.jmx"
      properties = hailstorm_config.jmeter.properties(test_plan: partial_attrs[:test_plan_name])
      obj[:properties] = properties.entries
    else
      obj[:id] = partial_attrs[:test_plan_name].to_java_string.hash_code
      obj[:name] = File.basename(partial_attrs[:test_plan_name])
      obj[:dataFile] = true
    end

    obj
  end

  def update_map(map, data)
    data['properties'].each { |name, value| map[name] = value }
  end
end
