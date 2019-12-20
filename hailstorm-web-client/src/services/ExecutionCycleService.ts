import { ExecutionCycleStatus, ExecutionCycle } from "../domain";
import environment from "../environment";

function reviver(key: string, value: any): any {
  return (value ? (key === 'startedAt' || key === 'stoppedAt' ? new Date(value) : value) : value);
}

export class ExecutionCycleService {

  async list(projectId: number): Promise<ExecutionCycle[]> {
    console.log(`api ---- ExecutionCycle#list(${projectId})`);
    try {
      const response = await fetch(`${environment.apiBaseURL}/projects/${projectId}/execution_cycles`);
      if (!response.ok) {
        throw new Error(response.statusText);
      }

      const responseText = await response.text();
      const data: ExecutionCycle[] = JSON.parse(responseText, reviver);
      return data;
    } catch (error) {
      throw new Error(error);
    }
  }

  async update(executionCycleId: number, projectId: number, attributes: {
    status?: ExecutionCycleStatus;
  }): Promise<ExecutionCycle> {
    console.log(`api ---- ExecutionCycleService#update(${executionCycleId}, ${projectId}, ${attributes})`);
    try {
      const response = await fetch(`${environment.apiBaseURL}/projects/${projectId}/execution_cycles/${executionCycleId}`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(attributes)
      });

      if (!response.ok) {
        throw new Error(response.statusText);
      }

      const responseText = await response.text();
      const data: ExecutionCycle = JSON.parse(responseText, reviver);
      return data;
    } catch (error) {
      throw new Error(error);
    }
  }
}
