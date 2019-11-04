import { subMinutes } from 'date-fns';
import {
  Project,
  ExecutionCycle,
  Report,
  ExecutionCycleStatus
} from "./domain";

const minutesAgo = (minutes: number, date?: Date): Date => subMinutes(date || new Date(), minutes);

function counter(begin: number) {
  return function() {
    return ++begin;
  }
}

export const DB: {
  projects: Project[];
  executionCycles: ExecutionCycle[];
  reports: Report[];
  sys: {
    projectIndex: {
      nextId: () => number;
    },

    jmeterIndex: {
      nextId: () => number;
    },

    clusterIndex: {
      nextId: () => number;
    }
  }
} = {
  projects: [
    {
      id: 1,
      code: "hailstorm_ocean",
      title:
        "Hailstorm Basic Priming test with Digital Ocean droplets and custom JMeter",
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
        startedAt: minutesAgo(120),
        stoppedAt: new Date(),
        status: ExecutionCycleStatus.STOPPED,
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
        startedAt: minutesAgo(45, new Date(2019, 11, 31, 10, 40, 18, 489)),
        stoppedAt: new Date(2019, 11, 31, 10, 40, 18, 489),
        status: ExecutionCycleStatus.ABORTED,
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
        startedAt: minutesAgo(4320, new Date(2019, 6, 30, 23, 30, 0, 897)),
        stoppedAt: new Date(2019, 6, 30, 23, 30, 0, 897),
        status: ExecutionCycleStatus.FAILED,
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
    },
  ],

  executionCycles: [
    {
      id: 1,
      projectId: 1,
      startedAt: new Date(2018, 11, 3, 10, 30, 49),
      stoppedAt: new Date(2018, 11, 3, 10, 35, 57),
      status: ExecutionCycleStatus.STOPPED,
      threadsCount: 25,
      responseTime: 74.78,
      throughput: 5.47
    },
    { id: 201, projectId: 7, startedAt: minutesAgo(60), threadsCount: 30 },
    {
      id: 202,
      projectId: 1,
      startedAt: minutesAgo(30),
      stoppedAt: new Date(),
      status: ExecutionCycleStatus.STOPPED,
      threadsCount: 80,
      responseTime: 674.78,
      throughput: 12.34
    },
    { id: 203, projectId: 2, startedAt: minutesAgo(15), threadsCount: 10 },
    { id: 204, projectId: 1, startedAt: minutesAgo(5), threadsCount: 100 }
  ],

  reports: [
    { id: 1, projectId: 1, title: "hailstorm-site-basic-1-2" },
    { id: 2, projectId: 1, title: "hailstorm-site-basic-2-5" },
    { id: 3, projectId: 1, title: "hailstorm-site-basic-1-5" }
  ],

  sys: {
    projectIndex: {
      nextId: counter(7)
    },

    jmeterIndex: {
      nextId: counter(10)
    },

    clusterIndex: {
      nextId: counter(23)
    }
  }
};