import React, { useContext, useState, useEffect } from 'react';
import { AppStateContext } from '../appStateContext';
import { NewProjectWizardState } from "../NewProjectWizard/domain";
import { selector } from '../NewProjectWizard/reducer';
import styles from '../NewProjectWizard/NewProjectWizard.module.scss';
import { CommitJMeterFileAction, AbortJMeterFileUploadAction, SetJMeterConfigurationAction } from './actions';
import { MergeJMeterFileAction, RemoveJMeterFileAction, FileRemoveInProgressAction } from './actions';
import { ApiFactory } from '../api';
import { SavedFile } from '../FileUpload/domain';
import { ValidationNotice, JMeterFile } from '../domain';
import { FileServer } from '../FileUpload/fileServer';
import { isUploadInProgress } from './isUploadInProgress';
import { Loader, LoaderSize } from '../Loader/Loader';
import { StepHeader } from './StepHeader';
import { StepContent } from './StepContent';
import { StepFooter } from './StepFooter';
import { FileRemoveConfirmation } from './FileRemoveConfirmation';

export const UPLOAD_ABORT_ENABLE_DELAY_MS = 5000;

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
      validateJMeterPlan({ file, dispatch, projectId: appState.activeProject!.id });
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

  const state = selector(appState);
  return (
    <>
    <StepHeader {...{state, setDisableAbort, dispatch, handleFileUpload, setUploadAborted, uploadAborted}} />
    <div className={styles.stepBody}>
      <StepContent {...{dispatch, state, setShowModal, setUploadAborted, disableAbort}} />
      <StepFooter {...{dispatch, state}} />
    </div>
    <FileRemoveConfirmation file={appState.wizardState!.activeJMeterFile!} {...{showModal, setShowModal, handleFileRemove}} />
    </>
  );
}

export function isNextDisabled(state: NewProjectWizardState): boolean {
  return (
    !state.activeProject!.jmeter ||
    state.activeProject!.jmeter.files.filter(value => !value.dataFile).length === 0 ||
    isBackDisabled(state)
  );
}

export function isBackDisabled(state: NewProjectWizardState): boolean {
  return (
    (state.wizardState!.activeJMeterFile &&
      isUploadInProgress(state.wizardState!.activeJMeterFile)) ||
    ((state.wizardState!.activeJMeterFile &&
      hasUnsavedProperties(state.wizardState!.activeJMeterFile)) ||
      (state.wizardState!.activeJMeterFile &&
        state.wizardState!.activeJMeterFile.removeInProgress !== undefined)) === true
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

async function validateJMeterPlan({ file, dispatch, projectId }: { file: SavedFile; dispatch: React.Dispatch<any>; projectId: any}) {
  try {
    const data = await ApiFactory().jmeterValidation().create({ name: file.originalName, path: file.id, projectId });
    return dispatch(new CommitJMeterFileAction({ name: file.originalName, properties: data.properties!, path: file.id }));
  }
  catch (reason) {
    if (Object.keys(reason).includes('validationErrors')) {
      const validationErrors: ValidationNotice[] = (reason['validationErrors'] as string[]).map((message) => ({
        type: 'error', message
      }));

      dispatch(new AbortJMeterFileUploadAction({ name: file.originalName, validationErrors }));
    }
    else {
      console.error(reason);
    }
  }
}
