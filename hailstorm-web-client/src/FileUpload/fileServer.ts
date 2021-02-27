import environment from '../environment';
import { fetchOK } from '../fetch-adapter';

export class RequestDelegate {
  constructor(
    public req: XMLHttpRequest,
    private resolve: (value?: any) => void,
    private reject: (reason?: any) => void,
    private progressCb?: (progress: number) => void
  ) {}

  readyStateChangeHandler() {
    if (this.req.readyState === this.req.DONE && this.req.status === 200) {
      this.progressCb && this.progressCb(100);
      this.resolve(JSON.parse(this.req.response));
    }
  }

  errorHandler() {
    this.progressCb && this.progressCb(0);
    this.reject(this.req.statusText ? this.req.statusText : 'Connection refused');
  }

  progressHandler(event: ProgressEvent<XMLHttpRequestEventTarget>) {
    if (!event.lengthComputable) return;
    this.progressCb && this.progressCb((event.loaded / event.total) * 100);
  }

  abortHandler() {
    this.progressCb && this.progressCb(0);
    this.reject('User aborted upload');
  }
}

export interface UploadRequest {
  build(): any;
}
export class UploadRequestBuilder implements UploadRequest{
  constructor(private delegate: RequestDelegate) {}

  build() {
    this.addEventListener("readystatechange", this.delegate.readyStateChangeHandler);
    this.addUploadListener("error", this.delegate.errorHandler);
    this.addUploadListener("progress", this.delegate.progressHandler);
    this.addUploadListener("abort", this.delegate.abortHandler);
  }

  private addEventListener<K extends keyof XMLHttpRequestEventMap>(
    type: K,
    listener: (ev: XMLHttpRequestEventMap[K]) => any
  ): void {
    this.delegate.req.addEventListener(type, listener.bind(this.delegate));
  }

  private addUploadListener<K extends keyof XMLHttpRequestEventTargetEventMap>(
    type: K,
    listener: (ev: ProgressEvent<XMLHttpRequestEventTarget>) => any
  ) {
    this.delegate.req.upload.addEventListener(type, listener.bind(this.delegate));
  }
}

export class FileUploadSaga<T> {
  private req: XMLHttpRequest;
  private promise: Promise<any> | undefined;

  constructor(
    private file: File,
    private uploadURL: string,
    private progressCb?: (progress: number) => void,
    private pathPrefix?: string
  ) {
    this.req = new XMLHttpRequest();
  }

  begin(promise?: Promise<any>) {
    const formData = this.createForm(this.file, this.pathPrefix);
    this.promise = promise || new Promise((resolve, reject) => this.upload(resolve, reject, formData));
    return this;
  }

  private upload(resolve: (value: any) => void, reject: (reason?: any) => void, formData: FormData) {
    const reqDelegate = new RequestDelegate(this.req, resolve, reject, this.progressCb);
    const builder = new UploadRequestBuilder(reqDelegate);
    builder.build();

    this.req.open("POST", this.uploadURL);
    this.req.send(formData);
  }

  then<TResult1 = T, TResult2 = never>(
    onfulfilled?: ((value: T) => TResult1 | PromiseLike<TResult1>) | null,
    onrejected?: ((reason: any) => TResult2 | PromiseLike<TResult2>) | null
  ): FileUploadSaga<T> {

    if (this.promise === undefined) {
      throw new Error(`saga must be begun before chaining actions`);
    }

    this.promise = this.promise.then(onfulfilled, onrejected);
    return this;
  }

  catch<TResult = never>(
    onrejected?: ((reason: any) => TResult | PromiseLike<TResult>) | null
  ): FileUploadSaga<T> {

    if (this.promise === undefined) {
      throw new Error(`saga must be begun before chaining exception handlers`);
    }

    this.promise = this.promise.catch(onrejected);
    return this;
  }

  private createForm(file: File, pathPrefix: string | undefined) {
    const formData = new FormData();
    formData.append("file", file, file.name);
    if (pathPrefix) {
      formData.append("prefix", pathPrefix);
    }

    return formData;
  }

  rollback() {
    this.req.abort();
  }
}

export const FileServer: {
  uploadURL: string;
  sendFile: (file: File, progressCb?: (progress: number) => void, pathPrefix?: string) => FileUploadSaga<any>;
  removeFile: (file: {name: string, path: string}) => Promise<any>;
} = {

  uploadURL: `${environment.fileServerBaseURL}/upload`,

  sendFile: function (file, progressCb, pathPrefix) {
    console.debug(`FileServer ---- .sendFile({name: ${file.name}})`);
    return new FileUploadSaga(file, this.uploadURL, progressCb, pathPrefix);
  },

  removeFile: (file) => {
    console.debug(`FileServer ---- .removeFile(${file})`);
    return fetchOK(`${environment.fileServerBaseURL}/${file.path}`, {
      method: 'DELETE'
    });
  }
};
