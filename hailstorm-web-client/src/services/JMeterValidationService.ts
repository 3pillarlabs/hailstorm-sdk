import { JMeterFileUploadState } from "../NewProjectWizard/domain";
import environment from "../environment";
import { reviver } from "./JMeterService";

export class JMeterValidationService {

  async create(attrs: JMeterFileUploadState): Promise<JMeterFileUploadState & {
    autoStop: boolean;
  }> {
    console.log(`api ---- JMeterValidationService#create(${attrs})`);
    try {
      const response = await fetch(`${environment.apiBaseURL}/jmeter_validations`, {
        body: JSON.stringify(attrs),
        headers: {
          'Content-Type': 'application/json'
        },
        method: 'POST'
      });

      if (!response.ok) {
        throw new Error(response.statusText);
      }

      const responseText = await response.text();
      const data = JSON.parse(responseText, (key, value) => {
        return value === null ? undefined : reviver(key, value)
      });

      return data;
    } catch (error) {
      throw new Error(error);
    }
  }
}
