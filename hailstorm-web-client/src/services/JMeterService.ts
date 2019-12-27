import { JMeter, JMeterFile } from "../domain";
import environment from "../environment";
import { fetchGuard, fetchOK } from "./fetch-adapter";

export function reviver(key: string, value: any): any {
  return key === 'properties' ? new Map(value) : value;
}

export class JMeterService {

  async list(projectId: number): Promise<JMeter> {
    console.log(`api ---- JMeterService#list(${projectId})`);
    return fetchGuard<JMeter>(async () => {
      const response = await fetchOK(`${environment.apiBaseURL}/projects/${projectId}/jmeter_plans`);
      const responseText = await response.text();
      const files: JMeterFile[] = JSON.parse(responseText, reviver);
      return { files };
    });
  }

  async create(projectId: number, attrs: JMeterFile): Promise<JMeterFile> {
    console.log(`api ---- JMeterService#create(${projectId}, ${attrs})`);
    return fetchGuard<JMeterFile>(async () => {
      const reqAttrs: any = { ...attrs };
      if (attrs.properties) {
        reqAttrs.properties = Array.from(attrs.properties);
      }

      const response = await fetchOK(`${environment.apiBaseURL}/projects/${projectId}/jmeter_plans`, {
        body: JSON.stringify(reqAttrs),
        headers: {
          'Content-Type': 'application/json'
        },
        method: 'POST'
      });

      const responseText = await response.text();
      const file: JMeterFile = JSON.parse(responseText, reviver);
      return file;
    });
  }

  async update(projectId: number, jmeterFileId: number, attrs: {
    [K in keyof JMeterFile]?: JMeterFile[K];
  }): Promise<JMeterFile> {
    console.log(`api ---- JMeterService#update(${projectId}, ${jmeterFileId}), ${attrs}`);
    return fetchGuard<JMeterFile>(async () => {
      const reqAttrs: any = { ...attrs };
      if (attrs.properties) {
        reqAttrs.properties = Array.from(attrs.properties);
      }

      const response = await fetchOK(`${environment.apiBaseURL}/projects/${projectId}/jmeter_plans/${jmeterFileId}`, {
        body: JSON.stringify(reqAttrs),
        headers: {
          'Content-Type': 'application/json'
        },
        method: 'PATCH'
      });

      const responseText = await response.text();
      const file: JMeterFile = JSON.parse(responseText, reviver);
      return file;
    });
  }

  async destroy(projectId: number, jmeterFileId: number) {
    console.log(`api ---- JMeterService#destroy(${projectId}, ${jmeterFileId})`);
    return fetchGuard<void>(async () => {
      await fetchOK(`${environment.apiBaseURL}/projects/${projectId}/jmeter_plans/${jmeterFileId}`, {
        method: 'DELETE'
      });
    });
  }
}
