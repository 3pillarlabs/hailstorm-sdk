import { ExecutionCycleStatus, ExecutionCycle } from "../domain";
import environment from "../environment";
import { fetchGuard, fetchOK } from "../fetch-adapter";

function reviver(key: string, value: any): any {
  return (value ? (key === 'startedAt' || key === 'stoppedAt' ? new Date(value) : value) : value);
}

export class ExecutionCycleService {

  async list(projectId: number): Promise<ExecutionCycle[]> {
    console.log(`api ---- ExecutionCycle#list(${projectId})`);
    return fetchGuard<ExecutionCycle[]>(async () => {
      const response = await fetchOK(`${environment.apiBaseURL}/projects/${projectId}/execution_cycles`);
      const responseText = await response.text();
      const data: ExecutionCycle[] = JSON.parse(responseText, reviver);
      return data;
    });
  }

  async update(executionCycleId: number, projectId: number, attributes: {
    status?: ExecutionCycleStatus;
  }): Promise<ExecutionCycle> {
    console.log(`api ---- ExecutionCycleService#update(${executionCycleId}, ${projectId}, ${attributes})`);
    return fetchGuard(async () => {
      const response = await fetchOK(`${environment.apiBaseURL}/projects/${projectId}/execution_cycles/${executionCycleId}`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(attributes)
      });

      const responseText = await response.text();
      const data: ExecutionCycle = JSON.parse(responseText, reviver);
      return data;
    });
  }

  /**
   * Fetch status of running tests of current execution cycle
   * @param projectId
   */
  async get(projectId: number): Promise<ExecutionCycle & { noRunningTests: boolean }> {
    console.log(`api ---- ExecutionCycleService#get(${projectId})`);
    return fetchGuard(async () => {
      const response = await fetchOK(`${environment.apiBaseURL}/projects/${projectId}/execution_cycles/current`);
      const responseText = await response.text();
      const data: ExecutionCycle & { noRunningTests: boolean } = JSON.parse(responseText, reviver);
      return data;
    });
  }
}
