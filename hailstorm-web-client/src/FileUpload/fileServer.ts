import environment from '../environment';

export const FileServer: {
  uploadURL: string;
  sendFile: (file: File, callback?: (progress: number) => void, httpReq?: XMLHttpRequest, pathPrefix?: string) => Promise<any>;
  removeFile: (file: {name: string, path: string}) => Promise<any>;
} = {

  uploadURL: `${environment.fileServerBaseURL}/upload`,

  sendFile: function (file, callback, httpReq, pathPrefix) {
    console.debug(`FileServer ---- .sendFile({name: ${file.name}})`);
    return new Promise((resolve, reject) => {
      const req = httpReq || new XMLHttpRequest();
      req.addEventListener("readystatechange", () => {
        if (req.readyState === req.DONE && req.status === 200) {
          callback && callback(100);
          resolve(JSON.parse(req.response));
        }
      });

      req.upload.addEventListener("error", () => {
        callback && callback(0);
        reject(req.statusText ? req.statusText : 'Connection refused');
      });

      req.upload.addEventListener("progress", (event) => {
        if (!event.lengthComputable) return;
        callback && callback((event.loaded / event.total) * 100);
      });

      req.upload.addEventListener("abort", () => {
        callback && callback(0);
        reject('User aborted upload');
      });

      const formData = new FormData();
      formData.append("file", file, file.name);
      if (pathPrefix) {
        formData.append("prefix", pathPrefix);
      }

      req.open("POST", this.uploadURL);
      req.send(formData);
    });
  },

  removeFile: (file) => {
    console.debug(`FileServer ---- .removeFile(${file})`);
    return new Promise(async (resolve, reject) => {
      try {
        await fetch(`${environment.fileServerBaseURL}/${file.path}`, {
          method: 'DELETE'
        });

        resolve();
      } catch (error) {
        reject(error);
      }
    });
  }
};
