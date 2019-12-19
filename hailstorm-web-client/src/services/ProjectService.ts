import { Project, ExecutionCycleStatus, ExecutionCycle } from "../domain";
import { DB } from "../db";
import environ from '../environment';

export type ProjectActions = 'stop' | 'abort' | 'start' | 'terminate';

const SLOW_FACTOR = 1;

export class ProjectService {

  async list(): Promise<Project[]> {
    console.log(`api ---- ProjectService#list()`);
    try {
      const response = await fetch(`${environ.apiBaseURL}/projects`);
      if (!response.ok) {
        throw(new Error(response.statusText));
      }

      const body = await response.text();
      const data: Project[] = JSON.parse(body, (key, value) => {
        if ((key === "startedAt" || key === "stoppedAt") && value !== undefined && value !== null) {
          return new Date(value);
        }

        return value;
      });

      return data;

    } catch (error) {
      throw(new Error(error));
    }
  }

  async get(id: number): Promise<Project> {
    console.log(`api ---- ProjectService#get(${id})`);
    try {
      const response = await fetch(`${environ.apiBaseURL}/projects/${id}`);
      if (!response.ok) {
        throw(new Error(response.statusText));
      }

      const body = await response.text();
      const data: Project = JSON.parse(body, (key, value) => {
        if ((key === "startedAt" || key === "stoppedAt") && value !== undefined && value !== null) {
          return new Date(value);
        }

        return value;
      });

      return data;
    } catch (error) {
      throw(new Error(error));
    }
  }

  async update(id: number, attributes: {
    title?: string;
    running?: boolean;
    action?: ProjectActions;
  }): Promise<number> {
    console.log(`api ---- ProjectService#update(${id}, ${Object.keys(attributes)}, ${Object.values(attributes)})`);
    try {
      const response = await fetch(`${environ.apiBaseURL}/projects/${id}`, {
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(attributes),
        method: 'PATCH'
      });

      if (!response.ok) {
        throw new Error(response.statusText);
      }

      return response.status;
    } catch (error) {
      throw new Error(error);
    }
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

  async create(attributes: {
    [K in keyof Project]?: Project[K];
  }): Promise<Project> {
    console.log(`api ---- ProjectService#create(${attributes})`);
    try {
      const response = await fetch(`${environ.apiBaseURL}/projects`, {
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(attributes),
        method: 'POST'
      });

      if (!response.ok) {
        throw new Error(response.statusText);
      }

      const created: Project = await response.json();
      return created;

    } catch (error) {
      throw new Error(error);
    }
  }
}
