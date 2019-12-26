import React, { useContext, useState, useEffect } from 'react';
import { AppStateContext } from '../appStateContext';
import { JMeterSetupCompletedAction } from '../NewProjectWizard/actions';
import { CancelLink, BackLink } from '../NewProjectWizard/WizardControls';
import { WizardTabTypes, NewProjectWizardState } from "../NewProjectWizard/domain";
import { JMeterPlanList } from '../JMeterPlanList';
import { selector } from '../NewProjectWizard/reducer';
import styles from '../NewProjectWizard/NewProjectWizard.module.scss';
import { FileUpload } from '../FileUpload';
import { AddJMeterFileAction, CommitJMeterFileAction, AbortJMeterFileUploadAction, SetJMeterConfigurationAction } from './actions';
import { MergeJMeterFileAction, SelectJMeterFileAction, RemoveJMeterFileAction, FileRemoveInProgressAction } from './actions';
import { ApiFactory } from '../api';
import { SavedFile } from '../FileUpload/domain';
import { ValidationNotice, JMeterFile } from '../domain';
import { Modal } from '../Modal';
import { FileServer } from '../FileUpload/fileServer';
import { isUploadInProgress } from './isUploadInProgress';
import { ActiveFileDetail } from './ActiveFileDetail';
import { Loader, LoaderSize } from '../Loader/Loader';

const UPLOAD_ABORT_ENABLE_DELAY_MS = 5000;

export const JMeterConfiguration: React.FC = () => {
  const {appState, dispatch} = useContext(AppStateContext);
  const [showModal, setShowModal] = useState(false);
  const [uploadAborted, setUploadAborted] = useState(false);
  const [disableAbort, setDisableAbort] = useState(true);

  useEffect(() => {
    if (appState.activeProject && appState.activeProject.jmeter === undefined) {
      ApiFactory()
        .jmeter()
        .list(appState.activeProject.id)
        .then((data) => dispatch(new SetJMeterConfigurationAction(data)));
    }
  }, []);

  const handleFileUpload = (file: SavedFile) => {
    const jmeterPlan = file.originalName.match(/\.jmx$/);
    if (jmeterPlan) {
      validateJMeterPlan({ file, dispatch });
    } else {
      saveDataFile({ dispatch, file, projectId: appState.activeProject!.id });
    }
  };

  const handleFileRemove = (file: JMeterFile) => {
    setShowModal(false);
    dispatch(new FileRemoveInProgressAction(file.name));
    destroyFile({ file, dispatch, projectId: appState.activeProject!.id });
  };

  if (appState.activeProject && appState.activeProject.jmeter === undefined) {
    return (<Loader size={LoaderSize.APP}/>);
  }

  return (
    <>
    <StepHeader {...{state: appState, setDisableAbort, dispatch, handleFileUpload, setUploadAborted, uploadAborted}} />
    <div className={styles.stepBody}>
      <StepContent {...{dispatch, state: appState, setShowModal, setUploadAborted, disableAbort}} />
      <StepFooter {...{dispatch, state: appState}} />
    </div>
    <FileRemoveConfirmation file={appState.wizardState!.activeJMeterFile!} {...{showModal, setShowModal, handleFileRemove}} />
    </>
  );
}

function StepHeader({
  state,
  setDisableAbort,
  dispatch,
  handleFileUpload,
  setUploadAborted,
  uploadAborted
}: {
  state: NewProjectWizardState;
  setDisableAbort: React.Dispatch<React.SetStateAction<boolean>>;
  dispatch: React.Dispatch<any>;
  handleFileUpload: (file: SavedFile) => void;
  setUploadAborted: React.Dispatch<React.SetStateAction<boolean>>;
  uploadAborted: boolean;
}) {
  return (
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
              dispatch(new AbortJMeterFileUploadAction({ name: file.name, uploadError: error }));
              setUploadAborted(false);
              setDisableAbort(true);
            }}
            disabled={isUploadInProgress(state.wizardState!.activeJMeterFile)}
            abort={uploadAborted}
            pathPrefix={state.activeProject!.id.toString()}
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
  );
}

function StepContent({
  dispatch,
  state,
  setShowModal,
  setUploadAborted,
  disableAbort
}: {
  dispatch: React.Dispatch<any>;
  state: NewProjectWizardState;
  setShowModal: React.Dispatch<React.SetStateAction<boolean>>;
  setUploadAborted: React.Dispatch<React.SetStateAction<boolean>>;
  disableAbort: boolean;
}) {

  return (
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
  );
}

function StepFooter({
  dispatch,
  state,
}: {
  dispatch: React.Dispatch<any>;
  state: NewProjectWizardState;
}) {
  return (
    <div className="level">
      <div className="level-left">
        <div className="level-item">
          <CancelLink {...{dispatch}} />
        </div>
        <div className="level-item">
          <BackLink
            {...{dispatch, tab: WizardTabTypes.Project}}
            disabled={ isBackDisabled(state) }
          />
        </div>
      </div>
      <div className="level-right">
        <div className="level-item">
          <button
            className="button is-primary"
            onClick={() => dispatch(new JMeterSetupCompletedAction())}
            disabled={ isNextDisabled(state) }
          >
            Next
          </button>
        </div>
      </div>
    </div>
  );
}

function isNextDisabled(state: NewProjectWizardState): boolean {
  return !state.activeProject!.jmeter ||
    state.activeProject!.jmeter.files.filter((value) => !value.dataFile).length === 0 ||
    (state.wizardState!.activeJMeterFile && isUploadInProgress(state.wizardState!.activeJMeterFile)) ||
    (state.wizardState!.activeJMeterFile && hasUnsavedProperties(state.wizardState!.activeJMeterFile) ||
      (state.wizardState!.activeJMeterFile && state.wizardState!.activeJMeterFile.removeInProgress !== undefined)) === true;
}

function isBackDisabled(state: NewProjectWizardState): boolean {
  return (state.wizardState!.activeJMeterFile && isUploadInProgress(state.wizardState!.activeJMeterFile)) ||
    (state.wizardState!.activeJMeterFile && hasUnsavedProperties(state.wizardState!.activeJMeterFile) ||
      (state.wizardState!.activeJMeterFile && state.wizardState!.activeJMeterFile.removeInProgress !== undefined)) === true;
}

function hasUnsavedProperties(file: JMeterFile) {
  return (
    file.properties &&
    Array.from(file.properties.values()).some((value) => (
      value === undefined || value.toString().trim().length === 0)
    )
  )
}

function FileRemoveConfirmation({
  showModal,
  setShowModal,
  handleFileRemove,
  file,
}: {
  showModal: boolean;
  setShowModal: React.Dispatch<React.SetStateAction<boolean>>;
  handleFileRemove: (file: JMeterFile) => void;
  file: JMeterFile;
}) {
  return (
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
                  <button className="button is-danger" onClick={() => handleFileRemove(file)}>
                    Yes, remove it
                  </button>
                </p>
              </div>
            </div>
          </article>
        </div>
      </div>
    </Modal>
  );
}

async function destroyFile({ file, projectId, dispatch }: { file: JMeterFile; projectId: number; dispatch: React.Dispatch<any>; }) {
  if (file.id) {
    try {
      await ApiFactory().jmeter().destroy(projectId, file.id);
    }
    catch (reason) {
      console.error(reason);
    }
  }

  try {
    await FileServer.removeFile({ name: file.name, path: file.path! });
    dispatch(new RemoveJMeterFileAction(file));
  }
  catch (reason_1) {
    console.error(reason_1);
  }
}

async function saveDataFile({ dispatch, file, projectId }: { dispatch: React.Dispatch<any>; file: SavedFile; projectId: number; }) {
  dispatch(new CommitJMeterFileAction({ name: file.originalName, dataFile: true, path: file.id }));
  try {
    const data = await ApiFactory().jmeter().create(projectId, { name: file.originalName, dataFile: true, path: file.id });
    dispatch(new MergeJMeterFileAction(data));
  }
  catch (reason) {
    console.error(reason);
  }
}

async function validateJMeterPlan({ file, dispatch }: { file: SavedFile; dispatch: React.Dispatch<any>; }) {
  try {
    const data = await ApiFactory().jmeterValidation().create({ name: file.originalName, path: file.id });
    return dispatch(new CommitJMeterFileAction({ name: file.originalName, properties: data.properties!, path: file.id }));
  }
  catch (reason) {
    if (Object.keys(reason).includes('validationErrors')) {
      const validationErrors = (reason['validationErrors'] as ValidationNotice[]);
      dispatch(new AbortJMeterFileUploadAction({ name: file.originalName, validationErrors }));
    }
    else {
      console.error(reason);
    }
  }
}
