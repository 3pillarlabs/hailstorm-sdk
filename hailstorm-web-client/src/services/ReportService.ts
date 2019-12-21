import { Report } from "../domain";
import environment from "../environment";

export class ReportService {

  async list(projectId: number): Promise<Report[]> {
    console.log(`api ---- ReportService#list(${projectId})`);
    try {
      const response = await fetch(`${environment.apiBaseURL}/projects/${projectId}/reports`);
      if (!response.ok) {
        throw new Error(response.statusText);
      }

      const reports: Report[] = await response.json();
      return reports;
    } catch (error) {
      throw new Error(error);
    }
  }

  async create(projectId: number, executionCycleIds: number[]): Promise<Report> {
    console.log(`api ---- ReportService#create(${projectId}, ${executionCycleIds})`);
    try {
      const response = await fetch(`${environment.apiBaseURL}/projects/${projectId}/reports`, {
        body: JSON.stringify(executionCycleIds),
        headers: {
          'Content-Type': 'application/json'
        },
        method: 'POST'
      });

      if (!response.ok) {
        throw new Error(response.statusText);
      }

      const report: Report = await response.json();
      return report;
    } catch (error) {
      throw new Error(error);
    }
  }
}
