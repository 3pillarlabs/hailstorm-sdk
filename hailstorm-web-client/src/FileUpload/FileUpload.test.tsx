import React from 'react';
import { shallow, mount } from 'enzyme';
import { FileUpload } from './FileUpload';
import { render, fireEvent, wait } from '@testing-library/react';
import { FileServer, FileUploadSaga } from './fileServer';

describe('<FileUpload />', () => {
  beforeEach(() => {
    jest.resetAllMocks();
  });

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
    const file = new File(['<xml></xml>'], "a.jmx", {type: "text/xml"});
    const saga = new FileUploadSaga(file, "https://upload.url");
    jest.spyOn(saga, 'begin').mockImplementation(() => {
      saga['promise'] = new Promise((resolve) => {
        onUploadProgress(100);
        resolve(file);
      });

      return saga;
    });

    const sendFileSpy = jest.spyOn(FileServer, "sendFile").mockReturnValue(saga);

    const {findByRole} = render(
      <FileUpload
        {...{onAccept, onFileUpload, onUploadError, onUploadProgress}}
      >
      </FileUpload>
    );

    const fileInput = await findByRole('File Upload');
    fireEvent.change(fileInput, {
      target: {
        files: [file]
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
    const file = new File(['<xml></xml>'], "a.jmx", {type: "text/xml"});
    const saga = new FileUploadSaga(file, "https://upload.url");
    jest.spyOn(saga, 'begin').mockImplementation(() => {
      saga['promise'] = new Promise((_, reject) => {
        reject("Server not found");
      });

      return saga;
    });

    const sendFileSpy = jest.spyOn(FileServer, "sendFile").mockReturnValue(saga);

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
        files: [file]
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

  it('should prevent automatic upload on drop if preventDefault is true', async () => {
    const onAccept = jest.fn();
    const onFileUpload = jest.fn();
    const onUploadError = jest.fn();
    const onUploadProgress = jest.fn();
    const file = new File(['<xml></xml>'], "a.jmx", {type: "text/xml"});
    const saga = new FileUploadSaga(file, "https://upload.url");
    jest.spyOn(saga, 'begin').mockImplementation(() => {
      saga['promise'] = new Promise((resolve) => {
        onUploadProgress(100);
        resolve(file);
      });

      return saga;
    });

    const sendFileSpy = jest.spyOn(FileServer, "sendFile").mockReturnValue(saga);

    const {findByRole} = render(
      <FileUpload
        {...{onAccept, onFileUpload, onUploadError, onUploadProgress}}
        preventDefault={true}
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
    expect(sendFileSpy).not.toBeCalled();
    expect(onUploadProgress).not.toBeCalled();
    expect(onFileUpload).not.toBeCalled();
  });

  it('should abort an upload on prop change', async () => {
    const file = new File(['<xml></xml>'], "a.jmx", {type: "text/xml"});
    const saga = new FileUploadSaga(file, "https://upload.url");
    saga['promise'] = Promise.resolve({id: 1, originalName: 'a.jmx'});
    jest.spyOn(FileUploadSaga.prototype, 'begin').mockReturnValue(saga);
    const spy = jest.spyOn(saga, 'rollback');
    jest.spyOn(FileServer, 'sendFile').mockReturnValue(saga);
    const onAccept = jest.fn();
    const q = render(
      <FileUpload {...{onAccept}}>
      </FileUpload>
    );

    const fileInput = await q.findByRole('File Upload');
    fireEvent.change(fileInput, {
      target: {
        files: [new File(['<xml></xml>'], "a.jmx", {type: "text/xml"})]
      }
    });

    await wait(() => expect(onAccept).toBeCalled);

    q.rerender(
      <FileUpload {...{onAccept}} abort={true}>
      </FileUpload>
    );

    expect(spy).toHaveBeenCalled();
  });
});
