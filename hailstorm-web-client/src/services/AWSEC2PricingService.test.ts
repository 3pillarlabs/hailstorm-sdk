import { AWSEC2PricingService } from "./AWSEC2PricingService";
import { AWSInstanceChoiceOption } from "../ClusterConfiguration/domain";

describe('AWSEC2PricingService', () => {
  it('should list EC2 pricing options', async () => {
    const spy = jest.spyOn(window, 'fetch').mockResolvedValueOnce(new Response(new Blob([
      JSON.stringify([
        { instanceType: "m5a.large", maxThreadsByInstance: 500, hourlyCostByInstance: 0.096, numInstances: 1 },
      { instanceType: "m5a.xlarge", maxThreadsByInstance: 1000, hourlyCostByInstance: 0.192, numInstances: 1 },
      ])
    ])));
    const service = new AWSEC2PricingService();
    const data = await service.list("us-east-1");
    expect(spy).toHaveBeenCalled();
    expect(data.length).toBeGreaterThan(0);
    expect(data[0]).toBeInstanceOf(AWSInstanceChoiceOption);
  });
});
