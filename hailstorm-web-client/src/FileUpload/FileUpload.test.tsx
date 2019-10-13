import React from 'react';
import { shallow, mount } from 'enzyme';
import { FileUpload } from './FileUpload';
import { render, fireEvent, wait } from '@testing-library/react';
import { FileServer } from './fileServer';
import { LocalFile } from './domain';

describe('<FileUpload />', () => {
  it('should render without crashing', () => {
    shallow(
      <FileUpload
        onAccept={jest.fn()}
        onFileUpload={jest.fn()}
        onUploadError={jest.fn()}
      />
    );
  });

  it('should upload a selected file', async () => {
    const onAccept = jest.fn();
    const onFileUpload = jest.fn();
    const onUploadError = jest.fn();
    const onUploadProgress = jest.fn();
    const uploadFinished = Promise.resolve();
    const sendFileSpy = jest.spyOn(FileServer, "sendFile").mockImplementation((_file, callback) => {
      callback(100);
      return uploadFinished;
    });

    const {findByRole} = render(
      <FileUpload
        {...{onAccept, onFileUpload, onUploadError, onUploadProgress}}
      >
      </FileUpload>
    );

    const fileInput = await findByRole('File Upload');
    fireEvent.change(fileInput, {
      target: {
        files: [new File(['<xml></xml>'], "a.jmx", {type: "text/xml"})]
      }
    });

    await wait(() => expect(onAccept).toBeCalled);
    await uploadFinished;
    expect(sendFileSpy).toBeCalled();
    expect(onUploadProgress).toBeCalled();
    expect(onFileUpload).toBeCalled();
    expect(onUploadError).not.toBeCalled();
  });

  it('should handle upload error', async () => {
    const onAccept = jest.fn();
    const onUploadError = jest.fn();
    const sendFileSpy = jest.spyOn(FileServer, "sendFile").mockImplementation(() => {
      return Promise.reject("Server not found");
    });

    const {findByRole} = render(
      <FileUpload
        onFileUpload={jest.fn()}
        {...{onUploadError, onAccept}}
      >
      </FileUpload>
    );

    const fileInput = await findByRole('File Upload');
    fireEvent.change(fileInput, {
      target: {
        files: [new File(['<xml></xml>'], "a.jmx", {type: "text/xml"})]
      }
    });

    await wait(() => expect(onUploadError).toBeCalled());
    expect(sendFileSpy).toBeCalled();
  });

  it('should disable the input if fileUpload is disabled', () => {
    const component = mount(
      <FileUpload
        onAccept={jest.fn()}
        onFileUpload={jest.fn()}
        onUploadError={jest.fn()}
        disabled={true}
      />
    );

    expect(component.find('input')).toBeDisabled();
  });

  test.todo('should cancel an upload in progress');
});
