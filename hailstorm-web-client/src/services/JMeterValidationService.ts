import { JMeterFileUploadState } from "../NewProjectWizard/domain";
import environment from "../environment";
import { reviver } from "./JMeterService";
import { fetchGuard, fetchOK } from "./fetch-adapter";

export class JMeterValidationService {

  async create(attrs: JMeterFileUploadState): Promise<JMeterFileUploadState & {
    autoStop: boolean;
  }> {
    console.log(`api ---- JMeterValidationService#create(${attrs})`);
    return fetchGuard(async () => {
      const response = await fetchOK(`${environment.apiBaseURL}/jmeter_validations`, {
        body: JSON.stringify(attrs),
        headers: {
          'Content-Type': 'application/json'
        },
        method: 'POST'
      });

      const responseText = await response.text();
      const data = JSON.parse(responseText, (key, value) => {
        return value === null ? undefined : reviver(key, value)
      });

      return data;
    });
  }
}
