import React from "react";
import { NewProjectWizardState } from "../NewProjectWizard/domain";
import styles from "../NewProjectWizard/NewProjectWizard.module.scss";
import { FileUpload } from "../FileUpload";
import { AddJMeterFileAction, AbortJMeterFileUploadAction } from "./actions";
import { SavedFile } from "../FileUpload/domain";
import { isUploadInProgress } from "./isUploadInProgress";
import { UPLOAD_ABORT_ENABLE_DELAY_MS } from "./JMeterConfiguration";

export function StepHeader({
  state,
  setDisableAbort,
  dispatch,
  handleFileUpload,
  setUploadAborted,
  uploadAborted,
}: {
  state: NewProjectWizardState;
  setDisableAbort: React.Dispatch<React.SetStateAction<boolean>>;
  dispatch: React.Dispatch<any>;
  handleFileUpload: (file: SavedFile) => void;
  setUploadAborted: React.Dispatch<React.SetStateAction<boolean>>;
  uploadAborted: boolean;
}) {
  return (
    <div className={`columns ${styles.stepHeader}`}>
      <div className="column is-10">
        <h3 className="title is-3">
          {state.activeProject!.title} &mdash; JMeter
        </h3>
      </div>
      <div className="column is-2">
        <FileUpload
          onAccept={(file) => {
            setDisableAbort(true);
            const dataFile: boolean = !file.name.match(/\.jmx$/);
            dispatch(new AddJMeterFileAction({ name: file.name, dataFile }));
            setTimeout(() => {
              setDisableAbort(false);
            }, UPLOAD_ABORT_ENABLE_DELAY_MS);
          }}
          onFileUpload={handleFileUpload}
          onUploadError={(file, error) => {
            dispatch(
              new AbortJMeterFileUploadAction({
                name: file.name,
                uploadError: error,
              })
            );
            setUploadAborted(false);
            setDisableAbort(true);
          }}
          disabled={isUploadInProgress(state.wizardState!.activeJMeterFile)}
          abort={uploadAborted}
          pathPrefix={state.activeProject!.code}
        >
          <button
            className="button is-link is-medium is-pulled-right"
            title="Upload .jmx and data files (like .csv)"
            disabled={isUploadInProgress(state.wizardState!.activeJMeterFile)}
          >
            Upload
          </button>
        </FileUpload>
      </div>
    </div>
  );
}
