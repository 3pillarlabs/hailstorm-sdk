import { ProjectService } from './ProjectService';
import { Project, ExecutionCycleStatus } from '../domain';
import { subMinutes } from 'date-fns';

describe('ProjectService', () => {
  beforeEach(() => {
    jest.resetAllMocks();
  })

  it('should list the projects', async () => {
    const projectListResponse: Project[] = [
      {id: 1, code: 'a', title: 'A', running: false},
      {id: 2, code: 'b', title: 'B', running: true, currentExecutionCycle: {
        id: 21, projectId: 2, startedAt: subMinutes(new Date(), 20)
      }}
    ];

    const responsePromise = Promise.resolve(new Response(new Blob([JSON.stringify(projectListResponse)])));
    const fetchSpy = jest.spyOn(window, 'fetch').mockReturnValue(responsePromise);
    const service = new ProjectService();
    const payload = await service.list();
    expect(fetchSpy).toHaveBeenCalled();
    expect(payload).toEqual(projectListResponse);
  });

  it('should return a rejected promise if list project fails', (done) => {
    const mockFetchError = "mock fetch error";
    jest.spyOn(window, 'fetch').mockReturnValueOnce(Promise.reject(mockFetchError));
    const service = new ProjectService();
    service.list().catch((error: Error) => {
      done();
      expect(error.message).toEqual(mockFetchError);
    });
  });

  it('should fetch a project', async () => {
    const project: Project = {
      id: 1,
      code: 'a',
      title: 'A',
      running: false,
      currentExecutionCycle: {
        id: 123,
        projectId: 1,
        startedAt: subMinutes(new Date(), 45),
        threadsCount: 100
      },
      lastExecutionCycle: {
        id: 122,
        projectId: 1,
        startedAt: subMinutes(new Date(), 180),
        stoppedAt: subMinutes(new Date(), 120),
        threadsCount: 90,
        responseTime: 12345.45,
        status: ExecutionCycleStatus.STOPPED,
        throughput: 123.67
      }
    };

    const responsePromise = Promise.resolve(new Response(new Blob([JSON.stringify(project, (key: string, value: any) => (
      value && value instanceof Date ? value.getMilliseconds() : value
    ))])));

    const fetchSpy = jest.spyOn(window, 'fetch').mockReturnValue(responsePromise);
    const service = new ProjectService();
    const payload = await service.get(1);
    expect(fetchSpy).toHaveBeenCalled();
    expect(payload).toEqual(project);
  });

  it('should update the title of a project', async () => {
    const responsePromise = Promise.resolve(new Response(null, {status: 204}));
    const fetchSpy = jest.spyOn(window, 'fetch').mockReturnValue(responsePromise);
    const service = new ProjectService();
    const status = await service.update(1, {title: "Hailstorm Priming with Digital Ocean and custom JMeter"});
    expect(fetchSpy).toHaveBeenCalled();
    expect(status).toEqual(204);
  });

  it('should update the running status of a project', async () => {
    const responsePromise = Promise.resolve(new Response(null, {status: 204}));
    const fetchSpy = jest.spyOn(window, 'fetch').mockReturnValue(responsePromise);
    const service = new ProjectService();
    const status = await service.update(1, {running: true});
    expect(fetchSpy).toHaveBeenCalled();
    expect(status).toEqual(204);
  });

  it('should start, stop and abort the execution cycle of a project', async () => {
    const responsePromise = Promise.resolve(new Response(null, {status: 204}));
    const fetchSpy = jest.spyOn(window, 'fetch').mockReturnValue(responsePromise);
    const service = new ProjectService();
    let status = await service.update(1, {action: 'start'});
    expect(fetchSpy).toHaveBeenCalled();
    expect(status).toEqual(204);

    status = await service.update(1, {action: 'stop'});
    expect(fetchSpy).toHaveBeenCalled();
    expect(status).toEqual(204);

    status = await service.update(1, {action: 'abort'});
    expect(fetchSpy).toHaveBeenCalled();
    expect(status).toEqual(204);

    status = await service.update(1, {action: 'terminate'});
    expect(fetchSpy).toHaveBeenCalled();
    expect(status).toEqual(204);
  });

  it('should create a project', async () => {
    const attrs: {[K in keyof Project]?: Project[K]} = { code: 'a', title: 'A' };
    const fetchSpy = jest.spyOn(window, 'fetch').mockResolvedValue(new Response(new Blob([JSON.stringify({
      ...attrs, id: 1, running: false
    })])));

    const service = new ProjectService();
    const created = await service.create(attrs);
    expect(fetchSpy).toHaveBeenCalled();
    expect(created.id).toEqual(1);
  });

  it('should delete a project', async () => {
    const fetchSpy = jest.spyOn(window, 'fetch').mockResolvedValue(new Response(null, {status: 204}));
    const service = new ProjectService();
    const status = await service.delete(1);
    expect(fetchSpy).toHaveBeenCalled();
    expect(status).toEqual(204);
  });
});
