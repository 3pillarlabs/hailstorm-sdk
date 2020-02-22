import React from 'react';
import { NewProjectWizardState } from "../NewProjectWizard/domain";
import { MergeJMeterFileAction } from './actions';
import { ApiFactory } from '../api';
import { JMeterFileMessage } from './JMeterFileMessage';
import { FormikActions } from 'formik';
import { JMeterFileDetail } from './JMeterFileDetail';

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
          path: state.wizardState!.activeJMeterFile!.path,
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

  return (
    <>
    {!state.wizardState!.activeJMeterFile && (
    <div className="notification is-info">
      There are no test plans or data files yet. You need to upload at least one test plan (.jmx) file.
    </div>)}

    {state.wizardState!.activeJMeterFile &&
    <JMeterFileMessage file={state.wizardState!.activeJMeterFile} {...{ setUploadAborted, disableAbort }} />}

    {state.wizardState!.activeJMeterFile &&
    <JMeterFileDetail
      {...{setShowModal, onSubmit}}
      jmeterFile={state.wizardState!.activeJMeterFile}
    />}
    </>
  );
}
