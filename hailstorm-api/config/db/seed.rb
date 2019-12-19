require 'hailstorm/model/execution_cycle'

module Seed

  def self.id_counter(start)
    ->() { start += 1 }
  end

  DB = {
      sys: {
        execution_cycle_idx: id_counter(205),
        project_idx: id_counter(8)
      },

      projects: [
          {
              id: 1,
              code: "hailstorm_ocean",
              title: "Hailstorm Basic Priming test with Digital Ocean droplets and custom JMeter",
              running: true,
              autoStop: false
          },
          {
              id: 2,
              code: "acme_endurance",
              title: "Acme Endurance",
              running: true,
              autoStop: true
          },
          {
              id: 3,
              code: "acme_30_burst",
              title: "Acme 30 Burst",
              running: false,
              lastExecutionCycle: {
                  id: 10,
                  startedAt: Time.now - 20.minutes,
                  stoppedAt: Time.now,
                  status: Hailstorm::Model::ExecutionCycle::States::STOPPED,
                  projectId: 3,
                  threadsCount: 25
              },
              autoStop: false
          },
          {
              id: 4,
              code: "acme_60_burst",
              title: "Acme 60 Burst",
              running: false,
              lastExecutionCycle: {
                  id: 23,
                  startedAt: Time.mktime(2019, 11, 31, 10, 40, 18, 489) - 45.minutes,
                  stoppedAt: Time.mktime(2019, 11, 31, 10, 40, 18, 489),
                  status: Hailstorm::Model::ExecutionCycle::States::ABORTED,
                  projectId: 4,
                  threadsCount: 3000
              },
              autoStop: true
          },
          {
              id: 5,
              code: "acme_90_burst",
              title: "Acme 90 Burst",
              running: false,
              autoStop: false,
              incomplete: true
          },
          {
              id: 6,
              code: "hailstorm_basic",
              title: "Hailstorm Basic",
              running: false,
              lastExecutionCycle: {
                  id: 12,
                  startedAt: Time.mktime(2019, 6, 30, 23, 30, 0, 897) - 4320.minutes,
                  stoppedAt: Time.mktime(2019, 6, 30, 23, 30, 0, 897),
                  status: Hailstorm::Model::ExecutionCycle::States::ABORTED,
                  projectId: 6,
                  threadsCount: 50
              },
              autoStop: true
          },
          {
              id: 7,
              code: "cadent_capacity",
              title: "Cadent Capacity",
              running: true,
              autoStop: false
          }
      ],

      executionCycles: [
          {
              id: 1,
              projectId: 1,
              startedAt: Time.mktime(2018, 11, 3, 10, 30, 49),
              stoppedAt: Time.mktime(2018, 11, 3, 10, 35, 57),
              status: Hailstorm::Model::ExecutionCycle::States::STOPPED,
              threadsCount: 25,
              responseTime: 74.78,
              throughput: 5.47
          },
          { id: 201, projectId: 7, startedAt: Time.now - 60.minutes, threadsCount: 30 },
          {
              id: 202,
              projectId: 1,
              startedAt: Time.now - 30.minutes,
              stoppedAt: Time.now,
              status: Hailstorm::Model::ExecutionCycle::States::STOPPED,
              threadsCount: 80,
              responseTime: 674.78,
              throughput: 12.34
          },
          { id: 203, projectId: 2, startedAt: Time.now - 15.minutes, threadsCount: 10 },
          { id: 204, projectId: 1, startedAt: Time.now - 5.minutes, threadsCount: 100 }
      ]
  }
end
