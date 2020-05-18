import { FileServer } from './fileServer';

describe('FileServer', () => {
  it('should upload to uploadURL', () => {
    Object.defineProperty(FileServer, "fetchURL", {
      value: function() {
        return this.uploadURL;
      },
      writable: false
    });

    const value = (FileServer as any).fetchURL();
    expect(value).toEqual(FileServer.uploadURL);
  });

  it('should remove a file', async () => {
    const spy = jest.spyOn(window, 'fetch').mockReturnValue(Promise.resolve(new Response(null, {status: 204})));
    await FileServer.removeFile({name: 'a.jmx', path: '12345'});
    expect(spy).toHaveBeenCalled();
  });

  it('should handle error on removing a file', async () => {
    const promise = Promise.resolve(new Response(null, {status: 404, statusText: 'Not Found'}));
    const spy = jest.spyOn(window, 'fetch').mockReturnValue(promise);
    try {
      await FileServer.removeFile({name: 'a.jmx', path: '12345'});
      fail('failed request not rejected');
    } catch (error) {
      expect(error).toBeDefined();
    }

    expect(spy).toHaveBeenCalled();
  });
});
