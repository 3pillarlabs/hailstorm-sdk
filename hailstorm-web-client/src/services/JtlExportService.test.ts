import { JtlFile } from "../domain";
import { JtlExportService } from './JtlExportService';

describe('JtlExportService', () => {
  it('should create an exported file', async () => {
    const spy = jest.spyOn(window, 'fetch').mockResolvedValueOnce(new Response(new Blob([JSON.stringify({
      title: 'a-1-2.zip', url: 'http://foo:23/123/a-1-2.zip'
    } as JtlFile)])));

    const service = new JtlExportService();
    const data = await service.create(1, [4,5,6]);
    expect(spy).toBeCalled();
    expect(data).toBeDefined();
  });
});
