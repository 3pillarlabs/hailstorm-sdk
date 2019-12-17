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
});
