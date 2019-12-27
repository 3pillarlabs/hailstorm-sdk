import { AWSInstanceChoiceOption } from "../ClusterConfiguration/domain";
import environment from "../environment";
import { fetchGuard, fetchOK } from "./fetch-adapter";

export class AWSEC2PricingService {
  async list(region: string): Promise<AWSInstanceChoiceOption[]> {
    console.log(`api ---- AWSEC2PricingService#list(${region})`);
    return fetchGuard<AWSInstanceChoiceOption[]>(async () => {
      const response = await fetchOK(`${environment.apiBaseURL}/aws_ec2_pricing_options/${region}`);
      const responseText = await response.text();
      return (JSON.parse(responseText) as Array<any>).map((attrs) => new AWSInstanceChoiceOption(attrs));
    });
  }
}
