import React from 'react';
import { useDropzone } from 'react-dropzone';
import { LocalFile } from './domain';
import { FileServer } from './fileServer';

export interface FileUploadProps {
  onAccept: (file: LocalFile) => void;
  onFileUpload: (file: LocalFile) => void;
  onUploadError: (file: LocalFile, error: any) => void;
  onUploadProgress?: (file: LocalFile, progress: number) => void;
  disabled?: boolean;
}

export function FileUpload({
  onAccept,
  onFileUpload,
  onUploadError,
  onUploadProgress,
  children,
  disabled
}: React.PropsWithChildren<FileUploadProps>) {

  const onDrop = (acceptedFiles: File[]) => {
    const file = acceptedFiles[0];
    onAccept(file);
    FileServer.sendFile(file, (progress) => {
      if (onUploadProgress) onUploadProgress(file, progress);
    })
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
