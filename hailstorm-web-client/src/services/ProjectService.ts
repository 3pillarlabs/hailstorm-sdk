import { Project } from "../domain";
import environvent from '../environment';
import { fetchGuard, fetchOK } from "./fetch-adapter";

export type ProjectActions = 'stop' | 'abort' | 'start' | 'terminate';

export class ProjectService {

  async list(): Promise<Project[]> {
    console.log(`api ---- ProjectService#list()`);
    return fetchGuard(async () => {
      const response = await fetchOK(`${environvent.apiBaseURL}/projects`);
      const body = await response.text();
      const data: Project[] = JSON.parse(body, (key, value) => {
        if ((key === "startedAt" || key === "stoppedAt") && value !== undefined && value !== null) {
          return new Date(value);
        }

        return value;
      });

      return data;
    });
  }

  async get(id: number): Promise<Project> {
    console.log(`api ---- ProjectService#get(${id})`);
    return fetchGuard(async () => {
      const response = await fetchOK(`${environvent.apiBaseURL}/projects/${id}`);
      const body = await response.text();
      const data: Project = JSON.parse(body, (key, value) => {
        if ((key === "startedAt" || key === "stoppedAt") && value !== undefined && value !== null) {
          return new Date(value);
        }

        return value;
      });

      return data;
    });
  }

  async update(id: number, attributes: {
    title?: string;
    running?: boolean;
    action?: ProjectActions;
  }): Promise<number> {
    console.log(`api ---- ProjectService#update(${id}, ${Object.keys(attributes)}, ${Object.values(attributes)})`);
    return fetchGuard(async () => {
      const response = await fetchOK(`${environvent.apiBaseURL}/projects/${id}`, {
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(attributes),
        method: 'PATCH'
      });

      return response.status;
    });
  }

  async delete(id: number) {
    console.log(`api ---- ProjectService#delete(${id})`);
    return fetchGuard(async () => {
      const response = await fetch(`${environvent.apiBaseURL}/projects/${id}`, {
        method: 'DELETE'
      });

      return response.status;
    });
  }

  async create(attributes: {
    [K in keyof Project]?: Project[K];
  }): Promise<Project> {
    console.log(`api ---- ProjectService#create(${attributes})`);
    return fetchGuard(async () => {
      const response = await fetchOK(`${environvent.apiBaseURL}/projects`, {
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(attributes),
        method: 'POST'
      });

      const created: Project = await response.json();
      return created;
    });
  }
}
