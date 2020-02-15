require 'sinatra'
require 'json'
require 'hailstorm/model/project'
require 'hailstorm/model/jmeter_plan'

post '/jmeter_validations' do
  request.body.rewind
  # @type [Hash]
  data = JSON.parse(request.body.read)
  response_data = Hash[data]
  params = data.transform_keys { |key| key.underscore.to_sym rescue key }
  project = Hailstorm::Model::Project.find(params[:project_id])
  local_file_path = Hailstorm.fs.fetch_file(file_id: params[:path],
                                            file_name: params[:name],
                                            to_path: Hailstorm.workspace(project.project_code).tmp_path)

  jmeter_plan = Hailstorm::Model::JmeterPlan.new(
    project: project,
    test_plan_name: File.strip_ext(params[:name]),
    active: true
  )

  jmeter_plan.validate_plan = true
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

  JSON.dump(response_data)
end
