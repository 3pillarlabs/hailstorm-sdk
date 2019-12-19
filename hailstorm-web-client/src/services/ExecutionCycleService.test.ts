import { ExecutionCycle, ExecutionCycleStatus } from "../domain";
import { ExecutionCycleService } from "./ExecutionCycleService";

describe('ExecutionCycleService', () => {
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
});
