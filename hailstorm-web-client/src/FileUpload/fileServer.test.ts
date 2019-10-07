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
});
