import { Project, ExecutionCycleStatus, ExecutionCycle, Report, JtlFile } from "./domain";

export type ProjectActions = 'stop' | 'abort' | 'start';
export type ResultActions = 'report' | 'export' | 'trash';

const minutesAgo = (minutes: number): Date => new Date(new Date().getTime() - (minutes * 60 * 1000));

const DB: {
  projects: Project[],
  executionCycles: ExecutionCycle[],
  reports: Report[],
} = {
  projects: [
    { id: 1, code: "hailstorm_ocean", title: "Hailstorm Basic Priming test with Digital Ocean droplets and custom JMeter", running: true, autoStop: false },
    { id: 2, code: "acme_endurance", title: "Acme Endurance", running: true, autoStop: true },
    { id: 3, code: "acme_30_burst", title: "Acme 30 Burst", running: false, recentExecutionCycle: {id: 10, startedAt: new Date(), stoppedAt: new Date(), status: ExecutionCycleStatus.STOPPED, projectId: 3}, autoStop: false },
    { id: 4, code: "acme_60_burst", title: "Acme 60 Burst", running: false, recentExecutionCycle: {id: 23, startedAt: new Date(), stoppedAt: new Date(), status: ExecutionCycleStatus.ABORTED, projectId: 4}, autoStop: true },
    { id: 5, code: "acme_90_burst", title: "Acme 90 Burst", running: false, autoStop: false },
    { id: 6, code: "hailstorm_basic", title: "Hailstorm Basic", running: false, recentExecutionCycle: {id: 12, startedAt: new Date(), stoppedAt: new Date(), status: ExecutionCycleStatus.FAILED, projectId: 6}, autoStop: true },
    { id: 7, code: "cadent_capacity", title: "Cadent Capacity", running: true, autoStop: false },
  ],

  executionCycles: [
    { id: 1, projectId: 1, startedAt: new Date(2018, 11, 3, 10, 30, 49), stoppedAt: new Date(2018, 11, 3, 10, 35, 57), status: ExecutionCycleStatus.STOPPED, threadsCount: 25, responseTime: 74.78, throughput: 5.47 },
    { id: 201, projectId: 7, startedAt: minutesAgo(60), threadsCount: 30 },
    { id: 202, projectId: 1, startedAt: minutesAgo(30), stoppedAt: new Date(), status: ExecutionCycleStatus.STOPPED, threadsCount: 80, responseTime: 674.78, throughput: 12.34 },
    { id: 203, projectId: 2, startedAt: minutesAgo(15), threadsCount: 10 },
    { id: 204, projectId: 1, startedAt: minutesAgo(5), threadsCount: 100 },
  ],

  reports: [
    {id: 1, projectId: 1, title: 'hailstorm-site-basic-1-2'},
    {id: 2, projectId: 1, title: 'hailstorm-site-basic-2-5'},
    {id: 3, projectId: 1, title: 'hailstorm-site-basic-1-5'},
  ]
}

// API
export class ApiService {

  singletonContext: {[K: string]: any} = {
    projects: new ProjectService(),
    executionCycles: new ExecutionCycleService(),
    reports: new ReportService(),
    jtlExports: new JtlExportService(),
  };

  projects() {
    return this.singletonContext['projects'] as ProjectService;
  }

  executionCycles() {
    return this.singletonContext['executionCycles'] as ExecutionCycleService;
  }

  reports() {
    return this.singletonContext['reports'] as ReportService;
  }

  jtlExports() {
    return this.singletonContext['jtlExports'] as JtlExportService;
  }
}

export class ProjectService {

  list(): Promise<Project[]> {
    console.log(`api ---- ProjectService#list()`);
    return new Promise((resolve, reject) => {
      setTimeout(() => resolve(DB.projects.map((x) => {
        const currentExecutionCycle:
          | ExecutionCycle
          | undefined = DB.executionCycles.find(
          exCycle => !exCycle.stoppedAt && exCycle.projectId === x.id
        );
        return {...x, currenExecutionCycle: currentExecutionCycle};
      })), 300);
    });
  }

  get(id: number): Promise<Project> {
    console.log(`api ---- ProjectService#get(${id})`);
    let matchedProject: Project | undefined = DB.projects.find((project) => project.id === id);
    return new Promise((resolve, reject) => {
      if (matchedProject) {
        setTimeout(() => resolve({...matchedProject} as Project), 100);
      } else {
        setTimeout(() => reject(new Error(`No Project found with id - ${id}`)), 500);
      }
    });
  }

  update(id: number, attributes: {title?: string, running?: boolean, action?: ProjectActions}): Promise<void> {
    console.log(`api ---- ProjectService#update(${id}, ${Object.keys(attributes)}, ${Object.values(attributes)})`);
    const matchedProject: Project | undefined = DB.projects.find((project) => id === project.id);
    let processingTime = 100;
    let dbOp: (() => any) | undefined = undefined;
    if (matchedProject) {
      if (attributes.title) matchedProject.title = attributes.title;
      if (attributes.running !== undefined) matchedProject.running = attributes.running;
      switch (attributes.action) {
        case 'start':
          processingTime = 30000;
          dbOp = () => DB.executionCycles.push({
            id: DB.executionCycles[DB.executionCycles.length - 1].id + 1,
            startedAt: new Date(),
            threadsCount: 100,
            projectId: id
          });
          break;

        case 'stop':
          processingTime = 30000;
          dbOp = () => {
            const index = DB.executionCycles.findIndex((x) => x.projectId === id && !x.stoppedAt);
            if (index < 0) return;

            DB.executionCycles[index].stoppedAt = new Date();
            DB.executionCycles[index].responseTime = 234.56;
            DB.executionCycles[index].status = ExecutionCycleStatus.STOPPED;
            DB.executionCycles[index].throughput = 10.24;
          }
          break;

        case 'abort':
          processingTime = 15000;
          dbOp = () => {
            const index = DB.executionCycles.findIndex((x) => x.projectId === id && !x.stoppedAt);
            if (index < 0) return;

            DB.executionCycles[index].stoppedAt = new Date();
            DB.executionCycles[index].status = ExecutionCycleStatus.ABORTED;
          }
          break;

        default:
          break;
      }
    }

    return new Promise((resolve, reject) => {
      if (matchedProject) {
        setTimeout(() => {
          if (dbOp) dbOp();
          resolve();
        }, processingTime / 10);
      } else {
        setTimeout(() => reject(new Error(`No Project found with id - ${id}`)), 500);
      }
    });
  }
}

export class ExecutionCycleService {

  list(projectId: number): Promise<ExecutionCycle[]> {
    console.log(`api ---- ExecutionCycle#list(${projectId})`);
    return new Promise(
      (resolve, reject) => setTimeout(
        () => resolve(DB.executionCycles
          .filter((x) => x.projectId === projectId && x.status !== ExecutionCycleStatus.ABORTED)
          .map((x) => ({...x}))), 300));
  }

  update(executionCycleId: number, projectId: number, attributes: {status?: ExecutionCycleStatus}): Promise<ExecutionCycle> {
    console.log(`api ---- ExecutionCycleService#update(${executionCycleId}, ${projectId}, ${attributes})`);
    const matchedCycle = DB.executionCycles.find((value) => value.id === executionCycleId && value.projectId === projectId);
    return new Promise((resolve, reject) => setTimeout(() => {
      if (matchedCycle) {
        if (attributes.status) matchedCycle.status = attributes.status;
        resolve(matchedCycle);
      } else {
        reject(new Error(`No execution cycle with id: ${executionCycleId}, projectId: ${projectId}`));
      }
    }, 100));
  }
}

export class ReportService {

  list(projectId: number) {
    return new Promise<Report[]>((resolve, reject) =>
      setTimeout(() => resolve(DB.reports.filter((report) => report.projectId === projectId).map((x) => ({...x}))), 700));
  }

  create(projectId: number, executionCycleIds: number[]): Promise<void> {
    console.log(`api ---- ExecutionCycles#report(${projectId}, ${executionCycleIds})`);
    return new Promise((resolve, reject) => setTimeout(() => {
      const project = DB.projects.find((value) => value.id === projectId);
      if (project) {
        const [firstExCid, lastExCid] = executionCycleIds.length === 1 ?
                                        [executionCycleIds[0], undefined] :
                                        [executionCycleIds[0], executionCycleIds[executionCycleIds.length - 1]];
        let title = `${project.code}-${firstExCid}`;
        if (lastExCid) title += `-${lastExCid}`;
        const incrementId = DB.reports[DB.reports.length - 1].id + 1;
        DB.reports.push({id: incrementId, projectId, title});
        resolve();
      } else {
        reject(new Error(`No project with id ${projectId}`));
      }
    }, 3000));
  }
}

export class JtlExportService {
  create(projectId: number, executionCycleIds: number[]): Promise<JtlFile> {
    console.log(`api ---- JtlExportService#create(${projectId}, ${executionCycleIds})`);
    return new Promise((resolve, reject) => setTimeout(() => {
      const project = DB.projects.find((value) => value.id === projectId);
      if (project) {
        const [firstExCid, lastExCid] = executionCycleIds.length === 1 ?
                                        [executionCycleIds[0], undefined] :
                                        [executionCycleIds[0], executionCycleIds[executionCycleIds.length - 1]];
        let title = `${project.code}-${firstExCid}`;
        if (lastExCid) title += `-${lastExCid}`;
        const fileExtn = lastExCid ? 'zip' : 'jtl';
        const fileName = `${title}.${fileExtn}`;
        resolve({title: fileName, url: `http://static.hailstorm.local/${fileName}`});
      } else {
        reject(new Error(`No project with id ${projectId}`));
      }
    }, 3000));
  }
}

const singletonContext: {[K: string]: any} = {
  apiService: new ApiService()
}

export function ApiFactory() {
  return singletonContext['apiService'] as ApiService;
}
