import React, { useContext, useState } from 'react';
import { AppStateContext } from '../appStateContext';
import { JMeterSetupCompletedAction } from '../NewProjectWizard/actions';
import { CancelLink, BackLink } from '../NewProjectWizard/WizardControls';
import { WizardTabTypes, JMeterFileUploadState, NewProjectWizardState } from "../NewProjectWizard/domain";
import { JMeterPlanList } from './JMeterPlanList';
import { selector } from '../NewProjectWizard/reducer';
import styles from '../NewProjectWizard/NewProjectWizard.module.scss';
import { FileUpload } from '../FileUpload';
import { AddJMeterFileAction, CommitJMeterFileAction, AbortJMeterFileUploadAction, MergeJMeterFileAction, SelectJMeterFileAction, RemoveJMeterFileAction, FileRemoveInProgressAction } from './actions';
import { ApiFactory } from '../api';
import { LocalFile } from '../FileUpload/domain';
import { ValidationNotice, JMeterFile } from '../domain';
import { JMeterPropertiesMap } from './JMeterPropertiesMap';
import { Modal } from '../Modal';
import { FileServer } from '../FileUpload/fileServer';

const UPLOAD_ABORT_ENABLE_DELAY_MS = 5000;

export const JMeterConfiguration: React.FC = () => {
  const {appState, dispatch} = useContext(AppStateContext);
  const state = selector(appState);
  const [showModal, setShowModal] = useState(false);
  const [uploadAborted, setUploadAborted] = useState(false);
  const [disableAbort, setDisableAbort] = useState(true);

  const handleFileUpload = (file: LocalFile) => {
    const jmeterPlan = file.name.match(/\.jmx$/);
    if (jmeterPlan) {
      ApiFactory()
        .jmeterValidation()
        .create({name: file.name})
        .then((data) => dispatch(new CommitJMeterFileAction({name: file.name, properties: data.properties!})))
        .catch((reason) => {
          if (Object.keys(reason).includes('validationErrors')) {
            const validationErrors = reason['validationErrors'] as ValidationNotice[];
            dispatch(new AbortJMeterFileUploadAction({name: file.name, validationErrors}));
          } else {
            console.error(reason);
          }
        });
    } else {
      dispatch(new CommitJMeterFileAction({name: file.name, dataFile: true}));
      ApiFactory()
        .jmeter()
        .create(appState.activeProject!.id, {
          name: file.name,
          dataFile: true
        })
        .then((data) => dispatch(new MergeJMeterFileAction(data)))
        .catch((reason) => console.error(reason));
    }
  };

  const handleFileRemove = (file: JMeterFile) => {
    setShowModal(false);
    dispatch(new FileRemoveInProgressAction(file.name));
    if (file.id) {
      ApiFactory()
        .jmeter()
        .destroy(appState.activeProject!.id, file.id)
        .then(() => FileServer.removeFile({name: file.name}))
        .then(() => dispatch(new RemoveJMeterFileAction(file)))
        .catch((reason) => console.error(reason));
    } else {
      FileServer.removeFile({
        name: file.name
      })
      .then(() => dispatch(new RemoveJMeterFileAction(file)))
      .catch((reason) => console.error(reason));
    }
  };

  return (
    <>
    <div className={`level ${styles.stepHeader}`}>
      <div className="level-left">
        <div className="level-item">
          <h3 className="title is-3">{state.activeProject!.title} &mdash; JMeter</h3>
        </div>
      </div>
      <div className="level-right">
        <div className="level-item">
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
              dispatch(new AbortJMeterFileUploadAction({name: file.name, uploadError: error}));
              setUploadAborted(false);
              setDisableAbort(true);
            }}
            disabled={isUploadInProgress(state.wizardState!.activeJMeterFile)}
            abort={uploadAborted}
          >
            <button
              className="button is-link is-medium"
              title="Upload .jmx and data files (like .csv)"
              disabled={isUploadInProgress(state.wizardState!.activeJMeterFile)}
            >
              Upload
            </button>
          </FileUpload>
        </div>
      </div>
    </div>
    <div className={styles.stepBody}>
      <div className={`columns ${styles.stepContent}`}>
        <div className="column is-two-fifths">
          <JMeterPlanList
            onSelect={(file) => dispatch(new SelectJMeterFileAction(file))}
            jmeter={state.activeProject!.jmeter}
            activeFile={state.wizardState!.activeJMeterFile}
          />
        </div>

        <div className="column is-three-fifths">
          <ActiveFileDetail {...{state, dispatch, setShowModal, setUploadAborted, disableAbort}} />
        </div>
      </div>
      <div className="level">
        <div className="level-left">
          <div className="level-item">
            <CancelLink {...{dispatch}} />
          </div>
          <div className="level-item">
            <BackLink
              {...{dispatch, tab: WizardTabTypes.Project}}
              disabled={
                (state.wizardState!.activeJMeterFile && isUploadInProgress(state.wizardState!.activeJMeterFile)) ||
                (state.wizardState!.activeJMeterFile && hasUnsavedProperties(state.wizardState!.activeJMeterFile) ||
                (state.wizardState!.activeJMeterFile && state.wizardState!.activeJMeterFile.removeInProgress !== undefined))
              }
            />
          </div>
        </div>
        <div className="level-right">
          <div className="level-item">
            <button
              className="button is-primary"
              onClick={() => dispatch(new JMeterSetupCompletedAction())}
              disabled={
                !state.activeProject!.jmeter ||
                state.activeProject!.jmeter.files.filter((value) => !value.dataFile).length === 0 ||
                (state.wizardState!.activeJMeterFile && isUploadInProgress(state.wizardState!.activeJMeterFile)) ||
                (state.wizardState!.activeJMeterFile && hasUnsavedProperties(state.wizardState!.activeJMeterFile) ||
                (state.wizardState!.activeJMeterFile && state.wizardState!.activeJMeterFile.removeInProgress !== undefined))
              }
            >
              Next
            </button>
          </div>
        </div>
      </div>
    </div>
    <Modal isActive={showModal}>
      <div className={`modal${showModal ? " is-active" : ""}`}>
        <div className="modal-background"></div>
        <div className="modal-content">
          <article className="message is-warning">
            <div className="message-body">
              <p>Are you sure you want to remove this file?</p>
              <div className="field is-grouped is-grouped-centered">
                <p className="control">
                  <a className="button is-primary" onClick={() => setShowModal(false)}>
                    No, keep it
                  </a>
                </p>
                <p className="control">
                  <button className="button is-danger" onClick={() => handleFileRemove(appState.wizardState!.activeJMeterFile!)}>
                    Yes, remove it
                  </button>
                </p>
              </div>
            </div>
          </article>
        </div>
      </div>
    </Modal>
    </>
  );
}

function ActiveFileDetail({
  state,
  dispatch,
  setShowModal,
  setUploadAborted,
  disableAbort
}: {
  state: NewProjectWizardState;
  dispatch: React.Dispatch<any>;
  setShowModal: React.Dispatch<React.SetStateAction<boolean>>;
  setUploadAborted: React.Dispatch<React.SetStateAction<boolean>>;
  disableAbort:boolean;
}) {
  return (
    <>
    {!state.wizardState!.activeJMeterFile && (
      <div className="notification is-info">
        There are no test plans or data files yet. You need to upload at least one test plan (.jmx) file.
      </div>
    )}

    {state.wizardState!.activeJMeterFile &&
      <ActiveJMeterFile file={state.wizardState!.activeJMeterFile} {...{setUploadAborted, disableAbort}} />}

    {
      state.wizardState!.activeJMeterFile &&
      state.wizardState!.activeJMeterFile.removeInProgress === undefined &&
      !state.wizardState!.activeJMeterFile.dataFile &&
      state.wizardState!.activeJMeterFile.properties && (
        <JMeterPropertiesMap
          headerTitle={`Set properties for ${state.wizardState!.activeJMeterFile.name}`}
          properties={state.wizardState!.activeJMeterFile.properties}
          onSubmit={(values, {setSubmitting}) => {
            setSubmitting(true);
            const promise = state.wizardState!.activeJMeterFile!.id === undefined ?
              ApiFactory()
                .jmeter()
                .create(state.activeProject!.id, {
                  name: state.wizardState!.activeJMeterFile!.name,
                  properties: new Map(Object.entries(values)),
                  dataFile: state.wizardState!.activeJMeterFile!.dataFile
                }) :
              ApiFactory()
                .jmeter()
                .update(
                  state.activeProject!.id,
                  state.wizardState!.activeJMeterFile!.id,
                  { properties: new Map(Object.entries(values)) }
                );

            promise
              .then((jmeterFile) => {
                dispatch(new MergeJMeterFileAction(jmeterFile));
              })
              .catch((reason) => console.error(reason))
              .then(() => setSubmitting(false));
          }}
          onRemove={() => setShowModal(true)}
        />
      )
    }

    {
      state.wizardState!.activeJMeterFile &&
      state.wizardState!.activeJMeterFile.removeInProgress === undefined &&
      state.wizardState!.activeJMeterFile.uploadError === undefined &&
      state.wizardState!.activeJMeterFile.dataFile &&
      !isUploadInProgress(state.wizardState!.activeJMeterFile) && (
        <div className="card">
          <header className="card-header">
            <p className="card-header-title">
              {state.wizardState!.activeJMeterFile.name}
            </p>
          </header>
          <footer className="card-footer">
            <div className="card-footer-item">
              <button className="button is-warning" onClick={() => setShowModal(true)} role="Remove File">Remove</button>
            </div>
          </footer>
        </div>
      )
    }
    </>
  );
}

function ActiveJMeterFile({
  file,
  setUploadAborted,
  disableAbort
}: {
  file: JMeterFileUploadState;
  setUploadAborted: React.Dispatch<React.SetStateAction<boolean>>;
  disableAbort:boolean;
}) {
  if (isUploadInProgress(file)) {
    return (
      <div className="notification is-warning">
        <div className="level">
          <div className="level-left">
            <div className="level-item">
              Uploading {file.name}... &nbsp; <i className="fas fa-circle-notch fa-spin"></i>
            </div>
          </div>
          <div className="level-right">
            <div className="level-item">
              <button
                disabled={disableAbort}
                className="button is-danger"
                role="Abort Upload"
                onClick={() => {
                  if (window.confirm && window.confirm("Are you sure you want to abort the upload?")) {
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
  } else if (file.removeInProgress) {
    return (
      <div className="notification is-warning">
        Removing {file.name}... <i className="fas fa-circle-notch fa-spin"></i>
      </div>
    )
  } else if (file.uploadError) {
    return (
      <div className="notification is-danger">
        Error uploading {file.name}. You should check your set up and try again. The error message was &mdash; <br/>
        <code>
        {typeof(file.uploadError) === 'object' && 'message' in file.uploadError ?
          file.uploadError.message :
          file.uploadError}
        </code>
      </div>
    )
  } else if (file.validationErrors) {
    return (
      <>
      {file.validationErrors.map(({type, message}) => (
      <div key={`${type}:${message}`} className={`notification is-${type === 'error' ? 'danger' : type}`}>
        {message}
      </div>
      ))}
      </>
    )
  }

  return null;
}

function isUploadInProgress(file?: JMeterFileUploadState) {
  if (!file) {
    return;
  }

  return (
    file.uploadProgress !== undefined &&
    file.uploadProgress < 100 &&
    !(file.uploadError || file.validationErrors)
  );
}

function hasUnsavedProperties(file: JMeterFile) {
  return (
    file.properties &&
    Array.from(file.properties.values()).some((value) => (
      value === undefined || value.toString().trim().length === 0)
    )
  )
}
