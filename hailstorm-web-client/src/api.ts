import { Project, ExecutionCycleStatus } from "./domain";

// API
class ApiService {

  singletonContext: {[K: string]: any} = {
    projects: new ProjectService()
  };

  projects() {
    return this.singletonContext['projects'] as ProjectService;
  }
}

class ProjectService {
  fakeProjects: Project[];

  constructor() {
    this.fakeProjects = [
      { id: 1, code: "hailstorm_ocean", title: "Hailstorm Basic Priming test with Digital Ocean droplets and custom JMeter", running: true },
      { id: 2, code: "acme_endurance", title: "Acme Endurance", running: true },
      { id: 3, code: "acme_30_burst", title: "Acme 30 Burst", running: false, recentExecutionCycle: {startedAt: new Date(), stoppedAt: new Date(), status: ExecutionCycleStatus.STOPPED} },
      { id: 4, code: "acme_60_burst", title: "Acme 60 Burst", running: false, recentExecutionCycle: {startedAt: new Date(), stoppedAt: new Date(), status: ExecutionCycleStatus.ABORTED} },
      { id: 5, code: "acme_90_burst", title: "Acme 90 Burst", running: false },
      { id: 6, code: "hailstorm_basic", title: "Hailstorm Basic", running: false, recentExecutionCycle: {startedAt: new Date(), stoppedAt: new Date(), status: ExecutionCycleStatus.FAILED} },
      { id: 7, code: "cadent_capacity", title: "Cadent Capacity", running: true },
    ];

  }

  list(): Promise<Project[]> {
    console.log(`ProjectService#list() called`);
    return new Promise((resolve, reject) => {
      setTimeout(() => resolve(this.fakeProjects), 300);
    });
  }

  get(id: number | string): Promise<Project> {
    console.log(`ProjectService#get(${id}) called`);
    let matchedProject: Project | undefined = this.fakeProjects.find((project) => project.id == id);
    return new Promise((resolve, reject) => {
      if (matchedProject) {
        setTimeout(() => resolve(matchedProject), 100);
      } else {
        setTimeout(() => reject(new Error(`No Project found with id - ${id}`)), 500);
      }
    });
  }

  update(id: number | string, attributes: {title?: string}): Promise<void> {
    console.log(`ProjectService#update(${id}, ${attributes}) called`);
    const matchedProject: Project | undefined = this.fakeProjects.find((project) => id == project.id);
    if (matchedProject) {
      if (attributes.title) matchedProject.title = attributes.title;
    }

    return new Promise((resolve, reject) => {
      if (matchedProject) {
        setTimeout(() => resolve(), 100);
      } else {
        setTimeout(() => reject(new Error(`No Project found with id - ${id}`)), 500);
      }
    });
  }
}

const singletonContext: {[K: string]: any} = {
  apiService: new ApiService()
}

export function ApiFactory() {
  return singletonContext['apiService'] as ApiService;
}
