require 'hailstorm/model/execution_cycle'

module Seed

  def self.id_counter(start)
    ->() {start += 1}
  end

  DB = {
      sys: {
          execution_cycle_idx: id_counter(205),
          project_idx: id_counter(8),
          report_idx: id_counter(4),
          jmeter_plan_idx: id_counter(11),
          cluster_idx: id_counter(228)
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
              autoStop: false
          },
          {
              id: 4,
              code: "acme_60_burst",
              title: "Acme 60 Burst",
              running: false,
              autoStop: true,
              incomplete: true
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
          {id: 201, projectId: 7, startedAt: Time.now - 60.minutes, threadsCount: 30},
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
          {id: 203, projectId: 2, startedAt: Time.now - 15.minutes, threadsCount: 10},
          {id: 204, projectId: 1, startedAt: Time.now - 5.minutes, threadsCount: 100},
          {
              id: 10,
              projectId: 3,
              startedAt: Time.now - 20.minutes,
              stoppedAt: Time.now,
              status: Hailstorm::Model::ExecutionCycle::States::STOPPED,
              threadsCount: 50,
              responseTime: 178.78,
              throughput: 15.47
          },
          {
              id: 23,
              projectId: 4,
              startedAt: Time.mktime(2019, 11, 31, 10, 40, 18, 489) - 45.minutes,
              stoppedAt: Time.mktime(2019, 11, 31, 10, 40, 18, 489),
              status: Hailstorm::Model::ExecutionCycle::States::ABORTED,
              threadsCount: 3000
          },
          {
              id: 12,
              projectId: 6,
              startedAt: Time.mktime(2019, 6, 30, 23, 30, 0, 897) - 4320.minutes,
              stoppedAt: Time.mktime(2019, 6, 30, 23, 30, 0, 897),
              status: Hailstorm::Model::ExecutionCycle::States::ABORTED,
              threadsCount: 50
          }
      ],

      reports: [
          {id: 1, projectId: 1, title: "hailstorm-site-basic-1-2"},
          {id: 2, projectId: 1, title: "hailstorm-site-basic-2-5"},
          {id: 3, projectId: 1, title: "hailstorm-site-basic-1-5"}
      ],

      jmeter_plans: [
          {id: 1, name: 'prime.jmx', properties: [["foo", "1"]], path: "12345", projectId: 1},
          {id: 2, name: 'data.csv', dataFile: true, path: "1234556", projectId: 1},
          {id: 3, name: 'acme-endurance.jmx', properties: [["bar", "10"]], path: "12545", projectId: 2},
          {id: 4, name: 'acme-burst.jmx', properties: [["bar", "10"]], path: "12545", projectId: 3},
          {id: 5, name: 'acme-60-burst.jmx', properties: [["baz", "100"]], path: "12545", projectId: 4},
          {id: 6, name: 'hailstorm-basic.jmx', properties: [["users", "100"]], path: "12545", projectId: 6},
          {id: 7, name: 'cadent.jmx', properties: [["groups", "10"]], path: "12545", projectId: 7},
      ],

      clusters: [
          {id: 223, title: 'AWS us-east-1', type: 'AWS', code: 'aws-223', projectId: 1},
          {id: 224, title: 'AWS us-west-1', type: 'AWS', code: 'aws-224', projectId: 2},
          {id: 225, title: 'AWS us-east-1', type: 'AWS', code: 'aws-225', projectId: 3},
          {id: 226, title: 'AWS us-east-1', type: 'AWS', code: 'aws-226', projectId: 6},
          {id: 227, title: 'AWS us-west-1', type: 'AWS', code: 'aws-227', projectId: 7},
      ],

      amazon_clouds: [
          {
              id: 223, accessKey: 'A', secretKey: 'S', instanceType: 't2.small', maxThreadsByInstance: 25,
              region: 'us-east-1'
          },
          {
              id: 224, accessKey: 'A', secretKey: 'S', instanceType: 'm5a.xlarge', maxThreadsByInstance: 1000,
              region: 'us-west-1'
          },
          {
              id: 225, accessKey: 'A', secretKey: 'S', instanceType: 'm5a.2xlarge', maxThreadsByInstance: 2000,
              region: 'us-east-1'
          },
          {
              id: 226, accessKey: 'A', secretKey: 'S', instanceType: 'm5a.2xlarge', maxThreadsByInstance: 2000,
              region: 'us-east-1'
          },
          {
              id: 227, accessKey: 'A', secretKey: 'S', instanceType: 'm5a.xlarge', maxThreadsByInstance: 1000,
              region: 'us-west-1'
          }
      ],

      data_centers: [

      ]
  }
end
