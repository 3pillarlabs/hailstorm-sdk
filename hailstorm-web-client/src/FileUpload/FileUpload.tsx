import React, { useEffect, useState } from 'react';
import { useDropzone } from 'react-dropzone';
import { SavedFile } from './domain';
import { FileServer } from './fileServer';

export interface FileUploadProps {
  onAccept: (file: File) => void;
  onFileUpload?: (file: SavedFile) => void;
  onUploadError?: (file: File, error: any) => void;
  onUploadProgress?: (file: File, progress: number) => void;
  disabled?: boolean;
  abort?: boolean;
  name?: string;
  preventDefault?: boolean;
  accept?: string | string[];
}

export function FileUpload({
  onAccept,
  onFileUpload,
  onUploadError,
  onUploadProgress,
  children,
  disabled,
  abort,
  name,
  preventDefault,
  accept
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
    if (preventDefault) {
      return;
    }

    const handleProgress = (progress: number) => {
      if (onUploadProgress) onUploadProgress(file, progress);
    };

    const _httpReq = new XMLHttpRequest();
    setHttpReq(_httpReq);
    FileServer
      .sendFile(file, handleProgress, _httpReq)
      .then((savedFile: SavedFile) => {
        onFileUpload && onFileUpload(savedFile);
      })
      .catch((reason) => {
        onUploadError && onUploadError(file, reason);
      });
  };

  const {getRootProps, getInputProps} = useDropzone({
    onDrop,
    multiple: false,
    accept,
    disabled
  });

  return (
    <div {...getRootProps()}>
      {children}
      <input name={name} role="File Upload" {...getInputProps({disabled})} />
    </div>
  );
}
