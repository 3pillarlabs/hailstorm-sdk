# Helper for JMeter API
module JMeterHelper

  JMX_FILE = /\.jmx$/

  # Predicate that returns true if the argument is a JMeter test plan
  # @param [String] test_plan_name
  def jmx_file?(test_plan_name)
    JMX_FILE.match(test_plan_name)
  end

  def to_jmeter_attributes(hailstorm_config, project_id, partial_attrs)
    obj = {}
    obj[:projectId] = project_id
    obj[:path] = File.dirname(partial_attrs[:test_plan_name])
    if partial_attrs[:jmx_file]
      obj[:id] = compute_test_plan_id(partial_attrs[:test_plan_name])
      obj[:name] = "#{File.basename(partial_attrs[:test_plan_name])}.jmx"
      properties = hailstorm_config.jmeter.properties(test_plan: partial_attrs[:test_plan_name])
      obj[:properties] = properties.entries
    else
      obj[:id] = compute_data_file_id(partial_attrs[:test_plan_name])
      obj[:name] = File.basename(partial_attrs[:test_plan_name])
      obj[:dataFile] = true
    end

    obj
  end

  def update_map(map, data)
    data['properties'].each { |name, value| map[name] = value }
  end

  def configure_jmeter(found_project, request)
    # @type [Hash]
    data = JSON.parse(request.body.read)
    project_config = ProjectConfiguration
                     .where(project_id: found_project.id)
                     .first_or_create!(stringified_config: deep_encode(Hailstorm::Support::Configuration.new))

    hailstorm_config = deep_decode(project_config.stringified_config)
    test_plan_name = "#{data['path']}/#{data['name']}"
    file_id = add_to_config(data, hailstorm_config, test_plan_name)
    project_config.update_attributes!(stringified_config: deep_encode(hailstorm_config))
    jmeter_attributes(data, file_id, found_project)
  end

  # @param [String] test_plan_name
  # @return [Integer]
  def compute_test_plan_id(test_plan_name)
    File.strip_ext(test_plan_name).to_java_string.hash_code
  end

  # @param [String] data_file_name
  # @return [Integer]
  def compute_data_file_id(data_file_name)
    data_file_name.to_java_string.hash_code
  end

  private

  def jmeter_attributes(data, file_id, found_project)
    jmeter_plan = {
      id: file_id,
      name: data['name'],
      path: data['path'],
      projectId: found_project.id
    }

    jmeter_plan[:properties] = data['properties'] if data['properties']
    jmeter_plan[:dataFile] = true if data['dataFile']
    jmeter_plan
  end

  def add_to_config(data, hailstorm_config, test_plan_name)
    file_id = nil
    if jmx_file?(test_plan_name)
      file_id = compute_test_plan_id(test_plan_name)
      hailstorm_config.jmeter do |jmeter|
        jmeter.add_test_plan(test_plan_name)
        jmeter.properties(test_plan: test_plan_name) { |map| update_map(map, data) } if data['properties']
      end
    else
      file_id = compute_data_file_id(test_plan_name)
      hailstorm_config.jmeter.data_files.push(test_plan_name)
    end

    file_id
  end

  # @param [Hailstorm::Model::JmeterPlan] jmeter_plan
  # @param [String] local_file_path
  # @param [Hash] response_data
  def validate_jmeter_plan(jmeter_plan, local_file_path, response_data)
    File.open(local_file_path, 'r') do |test_plan_io|
      jmeter_plan.jmeter_plan_io = test_plan_io
      jmeter_plan.validate
      if !jmeter_plan.errors.include?(:test_plan_name)
        response_data['properties'] = jmeter_plan.properties_map.entries
        response_data['autoStop'] = !jmeter_plan.loop_forever?
        status 200
      else
        response_data['validationErrors'] = jmeter_plan.errors.get(:test_plan_name)
        status 422
      end
    end
  end
end
