import { JMeterValidationService } from './JMeterValidationService';

describe('JMeterValidationService', () => {
  it('should extract properties for valid plan', async () => {
    jest.spyOn(window, 'fetch').mockResolvedValueOnce(new Response(new Blob([
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
      uploadProgress: 100,
      projectId: 1
    });

    expect(uploadState.properties).toBeDefined();
  });

  it('should show validation errors', async () => {
    const response = Promise.resolve<Response>(new Response(new Blob([
      JSON.stringify({validationErrors: ['Missing data writer']})
    ]), { status: 422, statusText: 'Unprocessable Entity' }));

    jest.spyOn(window, 'fetch').mockReturnValueOnce(response);
    const service = new JMeterValidationService();
    try {
      await service.create({
        name: "a.jmx",
        path: "1234",
        uploadProgress: 100,
        projectId: 1
      });

    } catch (error) {
      expect(error["validationErrors"]).toBeDefined();
    }
  });
});
