import _ from 'lodash';
import { FileServer, FileUploadSaga, RequestDelegate } from './fileServer';

describe('FileServer', () => {
  it('should upload to uploadURL', () => {
    expect(FileServer.uploadURL).toBeDefined();
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

  it('should upload a file', () => {
    const file = new File(['<xml></xml>'], "a.jmx", {type: "text/xml"});
    const saga = FileServer.sendFile(file, () => {}, '/');
    expect(saga).toBeDefined();
  });

  describe('FileUploadSaga', () => {
    type MockUploadResponse = {id: number, originalName: string};
    const uploadResponse: MockUploadResponse = {id: 1, originalName: 'a.jmx'};
    const file = new File(['<xml></xml>'], "a.jmx", {type: "text/xml"});

    it('should upload the file', () => {
      jest.spyOn(XMLHttpRequest.prototype, 'open');
      const sendSpy = jest.spyOn(XMLHttpRequest.prototype, 'send');
      const saga = new FileUploadSaga<MockUploadResponse>(
        file,
        'https://upload.url'
      );

      saga['upload'](jest.fn(), jest.fn(), new FormData());
      expect(sendSpy).toHaveBeenCalled();
    });

    it('should invoke actions on success', (done) => {
      const saga = new FileUploadSaga<MockUploadResponse>(
        file,
        'https://upload.url',
        undefined,
        '/foo'
      );

      saga.begin(Promise.resolve({...uploadResponse})).then((value) => {
        done();
        expect(value).toEqual({...uploadResponse});
      });
    });

    it('should invoke error handler on failure', (done) => {
      const saga = new FileUploadSaga<MockUploadResponse>(
        file,
        'https://upload.url'
      );

      const failureReason = "out of disk space";
      saga
        .begin(Promise.reject(failureReason))
        .then(() => fail("control should not reach here"))
        .catch((reason) => {
          done();
          expect(reason).toEqual(failureReason);
        });
    });

    it('should abort an upload', () => {
      const saga = new FileUploadSaga<MockUploadResponse>(
        file,
        'https://upload.url'
      );

      const spy = jest.spyOn(saga['req'], 'abort');
      saga.begin(Promise.resolve({...uploadResponse}));
      saga.rollback();
      expect(spy).toHaveBeenCalled();
    });

    it('should throw error without beginning', () => {
      const saga = new FileUploadSaga<MockUploadResponse>(
        file,
        'https://upload.url'
      );

      expect(() => saga.then()).toThrowError();
      expect(() => saga.catch()).toThrowError();
    });
  });

  describe('RequestDelegate', () => {
    const resolve = jest.fn();
    const reject = jest.fn();
    const progress = jest.fn();
    let req: {[K in keyof XMLHttpRequest]?: XMLHttpRequest[K]};
    let delegate: RequestDelegate;

    beforeEach(() => {
      jest.resetAllMocks();
      req = {};
      delegate = new RequestDelegate(req as XMLHttpRequest, resolve, reject, progress);
    })

    it('should update progress to 100 on success', () => {
      const data = {id: 1, fileName: "a.jmx"};
      _.merge(req, {readyState: req.DONE, status: 200, response: JSON.stringify(data)});
      delegate.readyStateChangeHandler();
      expect(progress).toHaveBeenCalledWith(100);
      expect(resolve).toBeCalledWith(data);
    });

    it('should update progress to 0 on error', () => {
      const statusText = 'out of disk space';
      _.merge(req, {statusText});
      delegate.errorHandler();
      expect(progress).toHaveBeenCalledWith(0);
      expect(reject).toHaveBeenCalledWith(statusText);
    });

    it('should provide interim progress updates', () => {
      const event: {[K in keyof ProgressEvent]?: ProgressEvent[K]} = {
        lengthComputable: true,
        loaded: 50,
        total: 100
      };

      delegate.progressHandler(event as ProgressEvent<XMLHttpRequestEventTarget>);
      expect(progress.mock.calls[0][0]).toBeCloseTo(50);
    });

    it('should update progress to 0 on abort', () => {
      delegate.abortHandler();
      expect(progress).toHaveBeenCalledWith(0);
      expect(reject).toHaveBeenCalled();
    });
  });
});
