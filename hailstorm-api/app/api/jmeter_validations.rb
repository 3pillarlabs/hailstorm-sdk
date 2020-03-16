require 'sinatra'
require 'json'
require 'hailstorm/model/project'
require 'hailstorm/model/jmeter_plan'
require 'helpers/jmeter_helper'

include JMeterHelper

post '/jmeter_validations' do
  request.body.rewind
  # @type [Hash]
  data = JSON.parse(request.body.read)
  response_data = Hash[data]
  params = data.transform_keys { |key| key.to_s.underscore.to_sym }
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
  validate_jmeter_plan(jmeter_plan, local_file_path, response_data)
  JSON.dump(response_data)
end
