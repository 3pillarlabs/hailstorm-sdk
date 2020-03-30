import { ReportService } from './ReportService';

describe('ReportService', () => {
  beforeEach(() => {
    jest.resetAllMocks();
  });

  it('should return list of reports', async () => {
    const spy = jest.spyOn(window, 'fetch').mockResolvedValueOnce(new Response(new Blob([JSON.stringify([
      { id: 1, projectId: 1, title: "hailstorm-site-basic-1-2", uri: "http://fs:1234/4567/hailstorm-site-basic-1-2.docx" },
    ])])));

    const service = new ReportService();
    const data = await service.list(1);
    expect(spy).toBeCalled();
    expect(data.length).toEqual(1);
  });

  it('should create a new project', async () => {
    const spy = jest.spyOn(window, 'fetch').mockResolvedValueOnce(new Response(new Blob([JSON.stringify(
      { id: 1, projectId: 1, title: "hailstorm-site-basic-2-4", uri: "http://fs:1234/5678/hailstorm-site-basic-2-4.docx" }
    )])));

    const service = new ReportService();
    const created = await service.create(1, [2, 3, 4]);
    expect(spy).toBeCalled();
    expect(created).toBeDefined();
  });
});
