# Helpers for creating fixtures for client_stats
module ClientStatsHelper

  # Creates the dependencies for a client_stat model
  def create_client_stat_refs(project = nil)
    project ||= Hailstorm::Model::Project.create!(project_code: 'execution_cycle_spec')
    execution_cycle = Hailstorm::Model::ExecutionCycle.create!(project: project,
                                                               status: :stopped,
                                                               started_at: Time.now,
                                                               stopped_at: Time.now + 15.minutes)
    jmeter_plan = Hailstorm::Model::JmeterPlan.create!(project: project,
                                                       test_plan_name: 'priming',
                                                       content_hash: 'A',
                                                       latest_threads_count: 100)
    jmeter_plan.update_column(:active, true)
    clusterable = Hailstorm::Model::AmazonCloud.create!(project: project,
                                                        access_key: 'A',
                                                        secret_key: 'A',
                                                        region: 'us-east-1')
    clusterable.update_column(:active, true)
    [clusterable, execution_cycle, jmeter_plan]
  end
end
