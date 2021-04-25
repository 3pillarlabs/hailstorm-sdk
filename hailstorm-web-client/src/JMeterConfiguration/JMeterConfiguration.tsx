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
import { AppNotificationContextProps, useNotifications } from '../app-notifications';

export const UPLOAD_ABORT_ENABLE_DELAY_MS = 5000;

export const JMeterConfiguration: React.FC = () => {
  const {appState, dispatch} = useContext(AppStateContext);
  const [showModal, setShowModal] = useState(false);
  const [uploadAborted, setUploadAborted] = useState(false);
  const [disableAbort, setDisableAbort] = useState(true);
  const notifiers = useNotifications();

  useEffect(() => {
    if (appState.activeProject && appState.activeProject.jmeter === undefined) {
      ApiFactory()
        .jmeter()
        .list(appState.activeProject.id)
        .then((data) => dispatch(new SetJMeterConfigurationAction(data)));
    }
  }, []);

  const handleFileUpload = (file: SavedFile) => {
    notifiers.notifySuccess(`File ${file.originalName} uploaded`);
    const jmeterPlan = file.originalName.match(/\.jmx$/);
    if (jmeterPlan) {
      validateJMeterPlan({ file, dispatch, projectId: appState.activeProject!.id, notifiers });
    } else {
      saveDataFile({ dispatch, file, projectId: appState.activeProject!.id, notifiers });
    }
  };

  const handleFileRemove = (file: JMeterFile) => {
    setShowModal(false);
    dispatch(new FileRemoveInProgressAction(file.name));
    destroyFile({ file, dispatch, projectId: appState.activeProject!.id, notifiers });
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
    state.activeProject!.jmeter.files.filter(value => !value.dataFile && !value.disabled).length === 0 ||
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

async function destroyFile({
  file,
  projectId,
  dispatch,
  notifiers
}: {
  file: JMeterFile;
  projectId: number;
  dispatch: React.Dispatch<any>;
  notifiers: AppNotificationContextProps;
}) {
  let removeFile = true;

  if (file.id) {
    try {
      await ApiFactory().jmeter().destroy(projectId, file.id);
      notifiers.notifySuccess(`Removed the ${file.dataFile ? 'data file' : 'JMeter plan'} from configuration`);
    }
    catch (reason) {
      removeFile = false;
      notifiers.notifyError("Failed to remove JMeter from configuration", reason);
    }
  }

  if (!removeFile) {
    return;
  }

  try {
    await FileServer.removeFile({ name: file.name, path: file.path! });
    notifiers.notifySuccess(`Deleted file ${file.name}`);
    dispatch(new RemoveJMeterFileAction(file));
  }
  catch (reason_1) {
    notifiers.notifyError(`Failed to remove file ${file.name}`, reason_1);
  }
}

async function saveDataFile({
  dispatch,
  file,
  projectId,
  notifiers
}: {
  dispatch: React.Dispatch<any>;
  file: SavedFile;
  projectId: number;
  notifiers: AppNotificationContextProps;
}) {
  dispatch(new CommitJMeterFileAction({ name: file.originalName, dataFile: true, path: file.id }));
  try {
    const data = await ApiFactory().jmeter().create(projectId, { name: file.originalName, dataFile: true, path: file.id });
    dispatch(new MergeJMeterFileAction(data));
    notifiers.notifySuccess(`JMeter data file ${data.name} saved`);
  }
  catch (reason) {
    notifiers.notifyError("Failed to save data file", reason);
  }
}

async function validateJMeterPlan({
  file,
  dispatch,
  projectId,
  notifiers
}: {
  file: SavedFile;
  dispatch: React.Dispatch<any>;
  projectId: any;
  notifiers: AppNotificationContextProps;
}) {
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
      notifiers.notifyError(`Failed to validate JMeter file`, reason);
    }
  }
}
