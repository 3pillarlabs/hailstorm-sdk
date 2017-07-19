json.array!(@test_plans) do |test_plan|
  json.extract! test_plan, :id, :project_id, :status, :default
  json.url test_plan_url(test_plan, format: :json)
end
