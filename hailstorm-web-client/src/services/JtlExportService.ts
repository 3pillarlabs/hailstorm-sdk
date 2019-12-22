import { JtlFile } from "../domain";
import environment from "../environment";

export class JtlExportService {
  async create(projectId: number, executionCycleIds: number[]): Promise<JtlFile> {
    console.log(`api ---- JtlExportService#create(${projectId}, ${executionCycleIds})`);
    try {
      const response = await fetch(`${environment.apiBaseURL}/projects/${projectId}/jtl_exports`, {
        body: JSON.stringify(executionCycleIds),
        headers: {
          'Content-Type': 'application/json'
        },
        method: 'POST'
      });

      if (!response.ok) {
        throw new Error(response.statusText);
      }

      const jtlFile: JtlFile = await response.json();
      return jtlFile;
    } catch (error) {
      throw new Error(error);
    }
  }
}
