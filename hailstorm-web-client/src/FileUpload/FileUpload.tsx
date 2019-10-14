import React, { useEffect, useState } from 'react';
import { useDropzone } from 'react-dropzone';
import { LocalFile } from './domain';
import { FileServer } from './fileServer';

export interface FileUploadProps {
  onAccept: (file: LocalFile) => void;
  onFileUpload: (file: LocalFile) => void;
  onUploadError: (file: LocalFile, error: any) => void;
  onUploadProgress?: (file: LocalFile, progress: number) => void;
  disabled?: boolean;
  abort?: boolean;
}

export function FileUpload({
  onAccept,
  onFileUpload,
  onUploadError,
  onUploadProgress,
  children,
  disabled,
  abort
}: React.PropsWithChildren<FileUploadProps>) {

  const [httpReq, setHttpReq] = useState<XMLHttpRequest | undefined>();
  useEffect(() => {
    if (!(abort && httpReq)) return;

    console.debug('FileUpload#useEffect(abort)');
    httpReq.abort();
  }, [abort]);

  const onDrop = (acceptedFiles: File[]) => {
    const file = acceptedFiles[0];
    onAccept(file);
    const handleProgress = (progress: number) => {
      if (onUploadProgress) onUploadProgress(file, progress);
    };

    const _httpReq = new XMLHttpRequest();
    setHttpReq(_httpReq);
    FileServer
      .sendFile(file, handleProgress, _httpReq)
      .then(() => onFileUpload(file))
      .catch((reason) => onUploadError(file, reason));
  };

  const {getRootProps, getInputProps} = useDropzone({
    onDrop,
    multiple: false
  });

  return (
    <div {...getRootProps()}>
      {children}
      <input role="File Upload" {...getInputProps()} {...{disabled}} />
    </div>
  );
}
