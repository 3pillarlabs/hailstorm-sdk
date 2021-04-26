import React from 'react';
import { JMeterFile } from '../domain';
import { JMeterPropertiesMap } from './JMeterPropertiesMap';
import { JMeterFileUploadState } from '../NewProjectWizard/domain';
import { isUploadInProgress } from './isUploadInProgress';
import { FormikActionsHandler } from './domain';

export function JMeterFileDetail({
  setShowModal,
  jmeterFile,
  onSubmit,
  headerTitle,
  toggleDisabled
}: {
  setShowModal?: React.Dispatch<React.SetStateAction<boolean>>;
  jmeterFile: JMeterFile;
  onSubmit?: FormikActionsHandler;
  headerTitle?: string;
  toggleDisabled?: (disabled: boolean) => void;
}) {
  return (
    <>
    {mayShowProperties(jmeterFile) && (
    <JMeterPropertiesMap
      headerTitle={headerTitle || `Set properties for ${jmeterFile!.name}`}
      properties={Array.from(jmeterFile!.properties!).map((value) => ({key: value[0], value: value[1]}))}
      onSubmit={onSubmit}
      onRemove={setShowModal ? () => setShowModal(true) : undefined}
      disabled={jmeterFile.disabled}
      planExecutedBefore={jmeterFile.planExecutedBefore}
      {...{toggleDisabled}}
      fileId={jmeterFile.id}
    />)}

    {isFileUploaded(jmeterFile) && (
    <div className="card">
      <header className="card-header">
        <p className="card-header-title">
          <span className="icon">
            <i className="far fa-file-code"></i>
          </span>
          {jmeterFile!.name}
        </p>
      </header>
      {setShowModal && (<footer className="card-footer">
        <div className="card-footer-item">
          <button
            className="button is-warning"
            onClick={() => setShowModal(true)}
            role="Remove File"
          >
            Remove
          </button>
        </div>
      </footer>)}
    </div>)}
    </>
  )
}

function isFileUploaded(jmeterFile?: JMeterFileUploadState): boolean {
  return jmeterFile &&
    jmeterFile.removeInProgress === undefined &&
    jmeterFile.uploadError === undefined &&
    jmeterFile.dataFile &&
    !isUploadInProgress(jmeterFile) ? true : false;
}

function mayShowProperties(jmeterFile?: JMeterFileUploadState): boolean {
  return jmeterFile &&
    jmeterFile.removeInProgress === undefined &&
    !jmeterFile.dataFile &&
    jmeterFile.properties ? true : false;
}
