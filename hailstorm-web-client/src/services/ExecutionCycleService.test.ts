import { ExecutionCycle, ExecutionCycleStatus } from "../domain";
import { ExecutionCycleService } from "./ExecutionCycleService";

describe('ExecutionCycleService', () => {
  beforeEach(() => {
    jest.resetAllMocks();
  });

  it('should list cycles for a project', async () => {
    const responseData: ExecutionCycle[] = [
      {
        id: 200,
        projectId: 1,
        startedAt: new Date(),
        stoppedAt: new Date(),
        threadsCount: 100,
        throughput: 10.24,
        responseTime: 12,
        status: ExecutionCycleStatus.STOPPED
      },
      {
        id: 201,
        projectId: 1,
        startedAt: new Date(),
        threadsCount: 200
      }
    ];

    const fetchSpy = jest.spyOn(window, 'fetch').mockResolvedValue(new Response(new Blob([JSON.stringify(responseData)])));
    const service = new ExecutionCycleService();
    const actualData = await service.list(1);
    expect(fetchSpy).toHaveBeenCalled();
    expect(actualData).toEqual(responseData);
  });

  it('should update an execution cycle', async () => {
    const executionCycle: ExecutionCycle = {
      id: 200,
      projectId: 1,
      startedAt: new Date(),
      stoppedAt: new Date(),
      threadsCount: 100,
      throughput: 10.24,
      responseTime: 12,
      status: ExecutionCycleStatus.STOPPED
    };

    const fetchSpy = jest.spyOn(window, 'fetch').mockResolvedValue(new Response(new Blob([JSON.stringify({
      ...executionCycle,
      status: ExecutionCycleStatus.EXCLUDED
    })])));

    const service = new ExecutionCycleService();
    const updated = await service.update(200, 1, {status: ExecutionCycleStatus.EXCLUDED});
    expect(fetchSpy).toHaveBeenCalled();
    expect(updated.status).toEqual(ExecutionCycleStatus.EXCLUDED);
  });

  it('should get status of current execution cycle', async () => {
    const executionCycle: ExecutionCycle = {
      id: 200,
      projectId: 1,
      startedAt: new Date(),
      threadsCount: 100
    };

    const fetchSpy = jest.spyOn(window, 'fetch').mockResolvedValue(new Response(new Blob([JSON.stringify({
      ...executionCycle,
      noRunningTests: true
    })])));

    const service = new ExecutionCycleService();
    const actual = await service.get(1);
    expect(actual.noRunningTests).toBeTruthy();
  });
});
