import { AWSInstanceChoiceOption } from "../ClusterConfiguration/domain";
import environment from "../environment";

export class AWSEC2PricingService {
  async list(region: string): Promise<AWSInstanceChoiceOption[]> {
    console.log(`api ---- AWSEC2PricingService#list(${region})`);
    try {
      const response = await fetch(`${environment.apiBaseURL}/aws_ec2_pricing_options/${region}`);
      if (!response.ok) {
        throw new Error(response.statusText);
      }

      const responseText = await response.text();
      return (JSON.parse(responseText) as Array<any>).map((attrs) => new AWSInstanceChoiceOption(attrs));
    } catch (error) {
      throw new Error(error);
    }
  }
}
