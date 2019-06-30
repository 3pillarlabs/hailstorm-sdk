import { Project, ExecutionCycleStatus } from "./domain";

// Project API
class ProjectService {
  constructor() {

  }

  list(): Promise<Project[]> {
    console.info('ProjectService#list called');
    const fakeProjects: Array<Project> = [
      { id: 1, code: "hailstorm_ocean", title: "Hailstorm Basic Priming test with Digital Ocean droplets and custom JMeter", running: true },
      { id: 2, code: "acme_endurance", title: "Acme Endurance", running: true },
      { id: 3, code: "acme_30_burst", title: "Acme 30 Burst", running: false, recentExecutionCycle: {startedAt: new Date(), stoppedAt: new Date(), status: ExecutionCycleStatus.STOPPED} },
      { id: 4, code: "acme_60_burst", title: "Acme 60 Burst", running: false, recentExecutionCycle: {startedAt: new Date(), stoppedAt: new Date(), status: ExecutionCycleStatus.ABORTED} },
      { id: 5, code: "acme_90_burst", title: "Acme 90 Burst", running: false },
      { id: 6, code: "hailstorm_basic", title: "Hailstorm Basic", running: false, recentExecutionCycle: {startedAt: new Date(), stoppedAt: new Date(), status: ExecutionCycleStatus.FAILED} },
      { id: 7, code: "cadent_capacity", title: "Cadent Capacity", running: true },
    ];

    return new Promise((resolve, _reject) => {
      setTimeout(() => resolve(fakeProjects), 3000);
    });
  }
}

export function ProjectServiceFactory() {
  return new ProjectService();
}
