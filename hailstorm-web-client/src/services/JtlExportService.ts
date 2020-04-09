import { JtlFile } from "../domain";
import environment from "../environment";
import { fetchGuard, fetchOK } from "./fetch-adapter";
import { replaceHost } from "./replaceHost";

export class JtlExportService {
  async create(projectId: number, executionCycleIds: number[]): Promise<JtlFile> {
    console.log(`api ---- JtlExportService#create(${projectId}, ${executionCycleIds})`);
    return fetchGuard(async () => {
      const response = await fetchOK(`${environment.apiBaseURL}/projects/${projectId}/jtl_exports`, {
        body: JSON.stringify(executionCycleIds),
        headers: {
          'Content-Type': 'application/json'
        },
        method: 'POST'
      });

      const jtlFile: JtlFile = await response.json();
      jtlFile.url = replaceHost(jtlFile.url);
      return jtlFile;
    });
  }
}
