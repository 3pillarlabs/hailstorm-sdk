import { JMeter, JMeterFile } from "../domain";
import { DB } from "../db";
import environment from "../environment";

const SLOW_FACTOR = 1;

export function reviver(key: string, value: any): any {
  return key === 'properties' ? new Map(value) : value;
}

export class JMeterService {

  async list(projectId: number): Promise<JMeter> {
    console.log(`api ---- JMeterService#list(${projectId})`);
    try {
      const response = await fetch(`${environment.apiBaseURL}/projects/${projectId}/jmeter_plans`);
      if (!response.ok) {
        throw new Error(response.statusText);
      }

      const responseText = await response.text();
      const files: JMeterFile[] = JSON.parse(responseText, reviver);
      return { files };
    } catch (error) {
      throw new Error(error);
    }
  }

  async create(projectId: number, attrs: JMeterFile): Promise<JMeterFile> {
    console.log(`api ---- JMeterService#create(${projectId}, ${attrs})`);
    try {
      const reqAttrs: any = { ...attrs };
      if (attrs.properties) {
        reqAttrs.properties = Array.from(attrs.properties);
      }

      const response = await fetch(`${environment.apiBaseURL}/projects/${projectId}/jmeter_plans`, {
        body: JSON.stringify(reqAttrs),
        headers: {
          'Content-Type': 'application/json'
        },
        method: 'POST'
      });

      if (!response.ok) {
        throw new Error(response.statusText);
      }

      const responseText = await response.text();
      const file: JMeterFile = JSON.parse(responseText, reviver);
      return file;
    } catch (error) {
      throw new Error(error);
    }
  }

  async update(projectId: number, jmeterFileId: number, attrs: {
    [K in keyof JMeterFile]?: JMeterFile[K];
  }): Promise<JMeterFile> {
    console.log(`api ---- JMeterService#update(${projectId}, ${jmeterFileId}), ${attrs}`);
    try {
      const reqAttrs: any = { ...attrs };
      if (attrs.properties) {
        reqAttrs.properties = Array.from(attrs.properties);
      }

      const response = await fetch(`${environment.apiBaseURL}/projects/${projectId}/jmeter_plans/${jmeterFileId}`, {
        body: JSON.stringify(reqAttrs),
        headers: {
          'Content-Type': 'application/json'
        },
        method: 'PATCH'
      });

      if (!response.ok) {
        throw new Error(response.statusText);
      }

      const responseText = await response.text();
      const file: JMeterFile = JSON.parse(responseText, reviver);
      return file;
    } catch (error) {
      throw new Error(error);
    }
  }

  async destroy(projectId: number, jmeterFileId: number) {
    console.log(`api ---- JMeterService#destroy(${projectId}, ${jmeterFileId})`);
    try {
      const response = await fetch(`${environment.apiBaseURL}/projects/${projectId}/jmeter_plans/${jmeterFileId}`, {
        method: 'DELETE'
      });

      if (!response.ok) {
        throw new Error(response.statusText);
      }
    } catch (error) {
      throw new Error(error);
    }
  }
}
