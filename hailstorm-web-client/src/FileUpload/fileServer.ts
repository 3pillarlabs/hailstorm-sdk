export const FileServer = {
  uploadURL: "https://slash-web-null.herokuapp.com/upload",
  sendFile: function (file: File, callback: (progress: number) => void) {
    return new Promise((resolve, reject) => {
      const req = new XMLHttpRequest();
      req.upload.addEventListener("load", () => {
        callback(100);
        resolve(req.response);
      });

      req.upload.addEventListener("error", () => {
        callback(0);
        reject(req.response);
      });

      req.upload.addEventListener("progress", event => {
        if (!event.lengthComputable) return;
        callback((event.loaded / event.total) * 100);
      });

      const formData = new FormData();
      formData.append("file", file, file.name);
      req.open("POST", this.uploadURL);
      req.send(formData);
    });
  }
};
