export const FileServer: {
  uploadURL: string;
  sendFile: (file: File, callback?: (progress: number) => void, httpReq?: XMLHttpRequest) => Promise<any>;
  removeFile: (file: {name: string}) => Promise<any>;
} = {

  uploadURL: "https://slash-web-null.herokuapp.com/upload",

  sendFile: function (file, callback, httpReq) {
    return new Promise((resolve, reject) => {
      const req = httpReq || new XMLHttpRequest();
      req.upload.addEventListener("load", () => {
        callback && callback(100);
        resolve(req.response);
      });

      req.upload.addEventListener("error", () => {
        callback && callback(0);
        reject(req.response);
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
      req.open("POST", this.uploadURL);
      req.send(formData);
    });
  },

  removeFile: (file) => {
    console.log(`FileServer ---- .removeFile(${file})`);
    return new Promise((resolve, reject) => {
      setTimeout(() => {
        resolve();
      }, 300);
    });
  }
};
