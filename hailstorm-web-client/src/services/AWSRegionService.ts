import { AWSRegionList } from "../ClusterConfiguration/domain";
import environment from "../environment";

export class AWSRegionService {

  async list(): Promise<AWSRegionList> {
    console.log(`api ---- AWSRegionService#list()`);
    try {
      const response = await fetch(`${environment.apiBaseURL}/aws_regions`);
      if (!response.ok) {
        throw new Error(response.statusText);
      }

      const regionData = await response.json();
      return regionData;
    } catch (error) {
      throw new Error(error);
    }
  }
}
