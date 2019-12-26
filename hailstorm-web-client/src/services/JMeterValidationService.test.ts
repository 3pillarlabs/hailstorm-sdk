import { JMeterValidationService } from './JMeterValidationService';

describe('JMeterValidationService', () => {
  it('should create a validation', async () => {
    const spy = jest.spyOn(window, 'fetch').mockResolvedValueOnce(new Response(new Blob([
      JSON.stringify({
        properties:[
          ["ThreadGroup.Admin.NumThreads", null],
          ["ThreadGroup.Users.NumThreads",null],
          ["Users.RampupTime",null]
        ],
        autoStop:false
      })
    ])));

    const service = new JMeterValidationService();
    const uploadState = await service.create({
      name: 'a.jmx',
      path: '1234',
      uploadProgress: 100
    });

    expect(uploadState.properties).toBeDefined();
  });
});
