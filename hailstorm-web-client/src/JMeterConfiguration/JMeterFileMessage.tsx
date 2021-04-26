import React from "react";
import { JMeterFileUploadState } from "../NewProjectWizard/domain";
import { isUploadInProgress } from "./isUploadInProgress";
import { ValidationNotice } from "../domain";

export function JMeterFileMessage({
  file,
  setUploadAborted,
  disableAbort
}: {
  file: JMeterFileUploadState;
  setUploadAborted: React.Dispatch<React.SetStateAction<boolean>>;
  disableAbort: boolean;
}) {
  let notification: JSX.Element | null = null;
  if (isUploadInProgress(file)) {
    notification = notifyUploadInProgress(file, disableAbort, setUploadAborted);
  } else if (file.removeInProgress) {
    notification = notifyRemovalInProgress(file);
  } else if (file.uploadError) {
    notification = notifyError(file);
  } else if (file.validationErrors) {
    notification = notifyValidationErrors(file.validationErrors!);
  }

  return notification;
}

function notifyValidationErrors(validationErrors: ValidationNotice[]) {
  return (
    <>
      {validationErrors.map(({ type, message }) => (
        <div
          key={`${type}:${message}`}
          className={`notification is-${type === "error" ? "danger" : type}`}
        >
          {message}
        </div>
      ))}
    </>
  );
}

function notifyError(file: JMeterFileUploadState) {
  return (
    <div className="notification is-danger">
      Error uploading {file.name}.You should check your set up and try again.The
      error message was &mdash; <br />
      <code>
        {typeof file.uploadError === "object" && "message" in file.uploadError
          ? file.uploadError.message
          : file.uploadError}
      </code>
    </div>
  );
}

function notifyRemovalInProgress(file: JMeterFileUploadState) {
  return (
    <div className="notification is-warning">
      Removing {file.name}... <i className="fas fa-circle-notch fa-spin"></i>
    </div>
  );
}

function notifyUploadInProgress(
  file: JMeterFileUploadState,
  disableAbort: boolean,
  setUploadAborted: React.Dispatch<React.SetStateAction<boolean>>
) {
  return (
    <div className="notification is-warning">
      <div className="level">
        <div className="level-left">
          <div className="level-item">
            Uploading {file.name}... &nbsp;{" "}
            <i className="fas fa-circle-notch fa-spin"></i>
          </div>
        </div>
        <div className="level-right">
          <div className="level-item">
            <button
              disabled={disableAbort}
              className="button is-danger"
              role="Abort Upload"
              onClick={() => {
                if (
                  window.confirm &&
                  window.confirm("Are you sure you want to abort the upload?")
                ) {
                  setUploadAborted(true);
                } else {
                  setUploadAborted(true);
                }
              }}
            >
              Abort
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
