import { JMeterService } from './JMeterService';
import { JMeterFile } from '../domain';

describe('JMeterService', () => {
  beforeEach(() => {
    jest.resetAllMocks();
  });

  it('should list JMeter plans in a project', async () => {
    const spy = jest.spyOn(window, 'fetch').mockResolvedValue(new Response(new Blob([
      JSON.stringify([
        {id: 1, name: 'prime.jmx', properties: [["foo", "1"], ["bar", "2"], ["baz", "3"]], path: "12345", projectId: 1},
        {id: 2, name: 'data.csv', dataFile: true, path: "1234556", projectId: 1},
      ])
    ])));

    const service = new JMeterService();
    const jmeter = await service.list(1);
    expect(spy).toHaveBeenCalled();
    expect(jmeter.files.length).toEqual(2);
    expect(jmeter.files[0].properties).toBeInstanceOf(Map);
    expect(jmeter.files[0].properties.size).toEqual(3);
  });

  it('should create JMeter plan in project', async () => {
    const spy = jest.spyOn(window, 'fetch').mockResolvedValue(new Response(new Blob([
      JSON.stringify({id: 100, name: 'prime.jmx', properties: [["foo", "1"], ["bar", "2"], ["baz", "3"]], path: "12345", projectId: 1})
    ])));

    const service = new JMeterService();
    const jmeterFile = await service.create(1, {
      name: 'prime.jmx',
      path: '12345',
      properties: new Map([["foo", "1"], ["bar", "2"], ["baz", "3"]])
    });

    const reqBody = JSON.parse(spy.mock.calls[0][1].body as string);
    expect(reqBody.properties).toEqual([["foo", "1"], ["bar", "2"], ["baz", "3"]]);
    expect(jmeterFile.id).toBeDefined();
  });

  it('should update JMeter plan in project', async () => {
    const spy = jest.spyOn(window, 'fetch').mockResolvedValue(new Response(new Blob([
      JSON.stringify({id: 100, name: 'prime.jmx', properties: [["foo", "1"], ["bar", "2"], ["baz", "3"]], path: "12345", projectId: 1})
    ])));

    const service = new JMeterService();
    service.update(1, 100, {
      properties: new Map([["foo", "1"], ["bar", "2"], ["baz", "3"]])
    });

    const reqBody = JSON.parse(spy.mock.calls[0][1].body as string);
    expect(reqBody.properties).toEqual([["foo", "1"], ["bar", "2"], ["baz", "3"]]);
  });

  it('should delete JMeter plan in project', async () => {
    const spy = jest.spyOn(window, 'fetch').mockResolvedValue(new Response(null, { status: 204 }));
    const service = new JMeterService();
    await service.destroy(1, 100);
    expect(spy).toBeCalled();
  });
});
