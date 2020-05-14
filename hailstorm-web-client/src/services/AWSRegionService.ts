import { AWSRegionList } from "../ClusterConfiguration/domain";
import environment from "../environment";
import { fetchGuard, fetchOK } from "../fetch-adapter";

export class AWSRegionService {

  async list(): Promise<AWSRegionList> {
    console.log(`api ---- AWSRegionService#list()`);
    return fetchGuard<AWSRegionList>(async () => {
      const response = await fetchOK(`${environment.apiBaseURL}/aws_regions`);
      const regionData = await response.json();
      return regionData;
    });
  }
}
