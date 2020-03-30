import { Report } from "../domain";
import environment from "../environment";
import { fetchGuard, fetchOK } from "./fetch-adapter";
import { replaceHost } from "./replaceHost";

export class ReportService {

  async list(projectId: number): Promise<Report[]> {
    console.log(`api ---- ReportService#list(${projectId})`);
    return fetchGuard(async () => {
      const response = await fetchOK(`${environment.apiBaseURL}/projects/${projectId}/reports`);
      const reports: Report[] = await response.json();
      return reports.map((report) => {
        report.uri = replaceHost(report.uri);
        return report;
      });
    })
  }

  async create(projectId: number, executionCycleIds: number[]): Promise<Report> {
    console.log(`api ---- ReportService#create(${projectId}, ${executionCycleIds})`);
    return fetchGuard(async () => {
      const response = await fetchOK(`${environment.apiBaseURL}/projects/${projectId}/reports`, {
        body: JSON.stringify(executionCycleIds),
        headers: {
          'Content-Type': 'application/json'
        },
        method: 'POST'
      });

      const report: Report = await response.json();
      report.uri = replaceHost(report.uri)
      return report;
    });
  }

}
