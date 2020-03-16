import { AWSRegionService } from './AWSRegionService';

describe('AWSRegionService', () => {
  it('should list regions and default region', async () => {
    const spy = jest.spyOn(window, 'fetch').mockResolvedValueOnce(new Response(new Blob([
      JSON.stringify({
        regions: [
          {
            code: 'North America',
            title: 'North America',
            regions: [
              { code: 'us-east-1', title: 'US East (Northern Virginia)' },
              { code: 'us-west-1', title: 'US West (Oregon)' },
            ]
          },
          {
            code: 'Europe/Middle East/Africa',
            title: 'Europe/Middle East/Africa',
            regions: [
              { code: 'eu-east-1', title: 'Europe (Ireland)' },
              { code: 'eu-central-1', title: 'Europe (Frankfurt)' },
              { code: 'eu-central-3', title: 'Europe (Paris)' },
            ]
          }
        ],
        defaultRegion: { code: 'us-east-1', title: 'US East (Northern Virginia)' }
      })
    ])));

    const service = new AWSRegionService();
    const data = await service.list();
    expect(spy).toHaveBeenCalled();
    expect(data.regions.length).toBeGreaterThan(0);
    expect(data.defaultRegion).toBeDefined();
  });
});
