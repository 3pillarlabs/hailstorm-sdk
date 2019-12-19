import { ProjectService } from './ProjectService';
import { Project } from '../domain';
import { subMinutes } from 'date-fns';

describe('ProjectService', () => {
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
    const project: Project = {id: 1, code: 'a', title: 'A', running: false}
    const responsePromise = Promise.resolve(new Response(new Blob([JSON.stringify(project)])));
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
});
