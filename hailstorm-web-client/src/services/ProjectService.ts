import { Project, ExecutionCycleStatus, ExecutionCycle } from "../domain";
import { DB } from "../db";
import environ from '../environment';

export type ProjectActions = 'stop' | 'abort' | 'start' | 'terminate';

const SLOW_FACTOR = 1;

export class ProjectService {

  list(): Promise<Project[]> {
    console.log(`api ---- ProjectService#list()`);
    return new Promise(async (resolve, reject) => {
      try {
        const response = await fetch(`${environ.apiBaseURL}/projects`);
        if (!response.ok) {
          reject(response.statusText);
          return;
        }

        const body = await response.text();
        const data: Project[] = JSON.parse(body, (key, value) => {
          if ((key === "startedAt" || key === "stoppedAt") && value !== undefined && value !== null) {
            return new Date(value);
          }

          return value;
        });

        resolve(data);
      } catch (error) {
        reject(error);
      }
    });
  }

  get(id: number): Promise<Project> {
    console.log(`api ---- ProjectService#get(${id})`);
    let matchedProject: Project | undefined = DB.projects.find((project) => project.id === id);
    return new Promise((resolve, reject) => {
      if (matchedProject) {
        setTimeout(() => resolve({ ...matchedProject } as Project), 100 * SLOW_FACTOR);
      }
      else {
        setTimeout(() => reject(new Error(`No Project found with id - ${id}`)), 500 * SLOW_FACTOR);
      }
    });
  }

  update(id: number, attributes: {
    title?: string;
    running?: boolean;
    action?: ProjectActions;
  }): Promise<void> {
    console.log(`api ---- ProjectService#update(${id}, ${Object.keys(attributes)}, ${Object.values(attributes)})`);
    const matchedProject: Project | undefined = DB.projects.find((project) => id === project.id);
    let processingTime = 100;
    let dbOp: (() => any) | undefined = undefined;
    if (matchedProject) {
      if (attributes.title)
        matchedProject.title = attributes.title;
      if (attributes.running !== undefined)
        matchedProject.running = attributes.running;
      switch (attributes.action) {
        case 'start':
          processingTime = 3000;
          dbOp = () => DB.executionCycles.push({
            id: DB.executionCycles[DB.executionCycles.length - 1].id + 1,
            startedAt: new Date(),
            threadsCount: 100,
            projectId: id
          });
          break;
        case 'stop':
          processingTime = 3000;
          dbOp = () => {
            const index = DB.executionCycles.findIndex((x) => x.projectId === id && !x.stoppedAt);
            if (index < 0)
              return;
            DB.executionCycles[index].stoppedAt = new Date();
            DB.executionCycles[index].responseTime = 234.56;
            DB.executionCycles[index].status = ExecutionCycleStatus.STOPPED;
            DB.executionCycles[index].throughput = 10.24;
          };
          break;
        case 'abort':
          processingTime = 1500;
          dbOp = () => {
            const index = DB.executionCycles.findIndex((x) => x.projectId === id && !x.stoppedAt);
            if (index < 0)
              return;
            DB.executionCycles[index].stoppedAt = new Date();
            DB.executionCycles[index].status = ExecutionCycleStatus.ABORTED;
          };
          break;
        case 'terminate':
          processingTime = 3000;
          dbOp = () => {
            const index = DB.executionCycles.findIndex((x) => x.projectId === id && !x.stoppedAt);
            if (index < 0)
              return;
            DB.executionCycles[index].stoppedAt = new Date();
            DB.executionCycles[index].status = ExecutionCycleStatus.ABORTED;
            matchedProject.running = false;
          };
          break;
        default:
          break;
      }
    }
    return new Promise((resolve, reject) => {
      if (matchedProject) {
        setTimeout(() => {
          if (dbOp)
            dbOp();
          resolve();
        }, processingTime * SLOW_FACTOR);
      }
      else {
        setTimeout(() => reject(new Error(`No Project found with id - ${id}`)), 500 * SLOW_FACTOR);
      }
    });
  }
  delete(id: number) {
    console.log(`api ---- ProjectService#delete(${id})`);
    return new Promise((resolve, reject) => {
      setTimeout(() => {
        const matchedProject: Project | undefined = DB.projects.find((project) => id === project.id);
        if (matchedProject) {
          DB.projects = DB.projects.filter((project) => project.id !== matchedProject.id);
          resolve();
        }
        else {
          reject(new Error(`No project with ID ${id}`));
        }
      }, 300 * SLOW_FACTOR);
    });
  }
  create({ title }: {
    [K in keyof Project]?: Project[K];
  }): Promise<Project> {
    console.log(`api ---- ProjectService#create(${title})`);
    return new Promise((resolve, reject) => {
      setTimeout(() => {
        if (title) {
          const newProject = {
            id: DB.sys.projectIndex.nextId(),
            autoStop: false,
            code: title.toLowerCase().replace(/\s+/, '-'),
            title,
            running: false
          };
          DB.projects.push(newProject);
          resolve({ ...newProject });
        }
        else {
          reject(new Error('Missing attributes: title'));
        }
      }, 100);
    });
  }
}
