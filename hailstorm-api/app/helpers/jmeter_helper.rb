# frozen_string_literal: true

require 'hailstorm/model/project'
require 'hailstorm/model/jmeter_plan'
require 'hailstorm/model/client_stat'

# Helper for JMeter API
module JMeterHelper

  JMX_FILE = /\.jmx$/.freeze

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
      properties = hailstorm_config.jmeter.properties(test_plan: partial_attrs[:test_plan_name])
      obj[:properties] = properties.entries
      add_jmx_attributes(obj, partial_attrs, project_id)
    else
      obj[:id] = compute_data_file_id(partial_attrs[:test_plan_name])
      obj[:name] = File.basename(partial_attrs[:test_plan_name])
      obj[:data_file] = true
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
    project_config.update!(stringified_config: deep_encode(hailstorm_config))
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

  # @param [Hash] data
  # @param [Hailstorm::Support::Configuration] hailstorm_config
  # @param [String] test_plan_name
  def handle_disabled(data, hailstorm_config, test_plan_name)
    return if data['disabled'].nil?

    if data['disabled']
      already_disabled = hailstorm_config.jmeter.disabled_test_plans.include?(test_plan_name)
      hailstorm_config.jmeter.disabled_test_plans.push(test_plan_name) unless already_disabled
    else
      hailstorm_config.jmeter.disabled_test_plans.reject! { |e| e == test_plan_name }
    end
  end

  # @param [Hailstorm::Support::Configuration] hailstorm_config
  # @param [String] test_plan_name
  # @param [Integer] project_id
  # @return [Hash]
  def build_patch_response(hailstorm_config, test_plan_name, project_id)
    path, name = test_plan_name.split('/')
    resp = { id: test_plan_name.to_java_string.hash_code,
             name: "#{name}.jmx",
             path: path,
             properties: hailstorm_config.jmeter.properties(test_plan: test_plan_name).entries,
             plan_executed_before: client_stats?(project_id, name) }

    resp[:disabled] = true if hailstorm_config.jmeter.disabled_test_plans.include?(test_plan_name)
    resp
  end

  # @param [Integer] project_id
  # @param [String] test_plan_name
  def client_stats?(project_id, test_plan_name)
    project = Hailstorm::Model::Project.find(project_id)
    test_plan = project.jmeter_plans.where(test_plan_name: test_plan_name).first
    test_plan && Hailstorm::Model::ClientStat.where(jmeter_plan_id: test_plan.id).count.positive?
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
    jmeter_plan[:data_file] = true if data['dataFile']
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
        response_data['validationErrors'] = jmeter_plan.errors[:test_plan_name]
        status 422
      end
    end
  end

  def add_jmx_attributes(obj, partial_attrs, project_id)
    obj[:id] = compute_test_plan_id(partial_attrs[:test_plan_name])
    obj[:name] = "#{File.basename(partial_attrs[:test_plan_name])}.jmx"
    obj[:disabled] = partial_attrs[:disabled] if partial_attrs.key?(:disabled)
    obj[:plan_executed_before] = client_stats?(project_id, File.basename(partial_attrs[:test_plan_name]))
  end
end
