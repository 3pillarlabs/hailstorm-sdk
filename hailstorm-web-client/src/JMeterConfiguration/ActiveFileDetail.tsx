import React from 'react';
import { NewProjectWizardState } from "../NewProjectWizard/domain";
import { MergeJMeterFileAction } from './actions';
import { ApiFactory } from '../api';
import { JMeterPropertiesMap } from './JMeterPropertiesMap';
import { ActiveJMeterFile } from './ActiveJMeterFile';
import { isUploadInProgress } from './isUploadInProgress';
import { FormikActions } from 'formik';

export function ActiveFileDetail({ state, dispatch, setShowModal, setUploadAborted, disableAbort }: {
  state: NewProjectWizardState;
  dispatch: React.Dispatch<any>;
  setShowModal: React.Dispatch<React.SetStateAction<boolean>>;
  setUploadAborted: React.Dispatch<React.SetStateAction<boolean>>;
  disableAbort: boolean;
}) {

  const onSubmit: (
    values: {[K: string]: any},
    actions: FormikActions<{[K: string]: any}>
  ) => void = (
    values,
    { setSubmitting }
  ) => {
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
        .update(state.activeProject!.id, state.wizardState!.activeJMeterFile!.id, { properties: new Map(Object.entries(values)) });

    promise
      .then((jmeterFile) => {
        dispatch(new MergeJMeterFileAction(jmeterFile));
      })
      .catch((reason) => console.error(reason))
      .then(() => setSubmitting(false));
  };

  return (<>
    {!state.wizardState!.activeJMeterFile && (
    <div className="notification is-info">
      There are no test plans or data files yet. You need to upload at least one test plan (.jmx) file.
    </div>)}

    {state.wizardState!.activeJMeterFile &&
      <ActiveJMeterFile file={state.wizardState!.activeJMeterFile} {...{ setUploadAborted, disableAbort }} />}

    {mayShowProperties(state) && (
      <JMeterPropertiesMap
        headerTitle={`Set properties for ${state.wizardState!.activeJMeterFile!.name}`}
        properties={state.wizardState!.activeJMeterFile!.properties!}
        onSubmit={onSubmit} onRemove={() => setShowModal(true)} />)}

    {isFileUploaded(state) && (
      <div className="card">
        <header className="card-header">
          <p className="card-header-title">
            {state.wizardState!.activeJMeterFile!.name}
          </p>
        </header>
        <footer className="card-footer">
          <div className="card-footer-item">
            <button className="button is-warning" onClick={() => setShowModal(true)} role="Remove File">Remove</button>
          </div>
        </footer>
      </div>)}
  </>);
}

function isFileUploaded(state: NewProjectWizardState): boolean {
  return state.wizardState!.activeJMeterFile &&
    state.wizardState!.activeJMeterFile.removeInProgress === undefined &&
    state.wizardState!.activeJMeterFile.uploadError === undefined &&
    state.wizardState!.activeJMeterFile.dataFile &&
    !isUploadInProgress(state.wizardState!.activeJMeterFile) ? true : false;
}

function mayShowProperties(state: NewProjectWizardState): boolean {
  return state.wizardState!.activeJMeterFile &&
    state.wizardState!.activeJMeterFile.removeInProgress === undefined &&
    !state.wizardState!.activeJMeterFile.dataFile &&
    state.wizardState!.activeJMeterFile.properties ? true : false;
}
