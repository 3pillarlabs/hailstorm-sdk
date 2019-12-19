import { ExecutionCycleStatus, ExecutionCycle } from "../domain";
import { DB } from "../db";
import environment from "../environment";

const SLOW_FACTOR = 1;

export class ExecutionCycleService {

  async list(projectId: number): Promise<ExecutionCycle[]> {
    console.log(`api ---- ExecutionCycle#list(${projectId})`);
    try {
      const response = await fetch(`${environment.apiBaseURL}/projects/${projectId}/execution_cycles`);
      if (!response.ok) {
        throw new Error(response.statusText);
      }

      const responseText = await response.text();
      const data: ExecutionCycle[] = JSON.parse(responseText, (key, value) => (
        value ? (key === 'startedAt' || key === 'stoppedAt' ? new Date(value) : value) : value
      ));

      return data;
    } catch (error) {
      throw new Error(error);
    }
  }

  update(executionCycleId: number, projectId: number, attributes: {
    status?: ExecutionCycleStatus;
  }): Promise<ExecutionCycle> {
    console.log(`api ---- ExecutionCycleService#update(${executionCycleId}, ${projectId}, ${attributes})`);
    const matchedCycle = DB.executionCycles.find((value) => value.id === executionCycleId && value.projectId === projectId);
    return new Promise((resolve, reject) => setTimeout(() => {
      if (matchedCycle) {
        if (attributes.status)
          matchedCycle.status = attributes.status;
        resolve(matchedCycle);
      }
      else {
        reject(new Error(`No execution cycle with id: ${executionCycleId}, projectId: ${projectId}`));
      }
    }, 100 * SLOW_FACTOR));
  }
}
