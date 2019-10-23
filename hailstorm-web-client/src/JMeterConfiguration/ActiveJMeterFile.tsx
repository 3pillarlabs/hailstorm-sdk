import React from 'react';
import { JMeterFileUploadState } from "../NewProjectWizard/domain";
import { isUploadInProgress } from './isUploadInProgress';

export function ActiveJMeterFile({ file, setUploadAborted, disableAbort }: {
  file: JMeterFileUploadState;
  setUploadAborted: React.Dispatch<React.SetStateAction<boolean>>;
  disableAbort: boolean;
}) {
  if (isUploadInProgress(file)) {
    return (<div className="notification is-warning">
      <div className="level">
        <div className="level-left">
          <div className="level-item">
            Uploading {file.name}... &nbsp; <i className="fas fa-circle-notch fa-spin"></i>
          </div>
        </div>
        <div className="level-right">
          <div className="level-item">
            <button disabled={disableAbort} className="button is-danger" role="Abort Upload" onClick={() => {
              if (window.confirm && window.confirm("Are you sure you want to abort the upload?")) {
                setUploadAborted(true);
              }
              else {
                setUploadAborted(true);
              }
            }}>
              Abort
              </button>
          </div>
        </div>
      </div>
    </div>);
  }
  else if (file.removeInProgress) {
    return (<div className="notification is-warning">
      Removing {file.name}... <i className="fas fa-circle-notch fa-spin"></i>
    </div>);
  }
  else if (file.uploadError) {
    return (<div className="notification is-danger">
      Error uploading {file.name}. You should check your set up and try again. The error message was &mdash; <br />
      <code>
        {typeof (file.uploadError) === 'object' && 'message' in file.uploadError ?
          file.uploadError.message :
          file.uploadError}
      </code>
    </div>);
  }
  else if (file.validationErrors) {
    return (<>
      {file.validationErrors.map(({ type, message }) => (<div key={`${type}:${message}`} className={`notification is-${type === 'error' ? 'danger' : type}`}>
        {message}
      </div>))}
    </>);
  }
  return null;
}
