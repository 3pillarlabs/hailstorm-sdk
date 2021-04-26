import React from 'react';
import { NewProjectWizardState } from "../NewProjectWizard/domain";
import { DisableJMeterFileAction, EnableJMeterFileAction, MergeJMeterFileAction } from './actions';
import { ApiFactory } from '../api';
import { JMeterFileMessage } from './JMeterFileMessage';
import { JMeterFileDetail } from './JMeterFileDetail';
import { FormikActionsHandler } from './domain';
import { useNotifications } from '../app-notifications';

export function ActiveFileDetail({ state, dispatch, setShowModal, setUploadAborted, disableAbort }: {
  state: NewProjectWizardState;
  dispatch: React.Dispatch<any>;
  setShowModal: React.Dispatch<React.SetStateAction<boolean>>;
  setUploadAborted: React.Dispatch<React.SetStateAction<boolean>>;
  disableAbort: boolean;
}) {
  const notifiers = useNotifications();

  const onSubmit: FormikActionsHandler = (
    values,
    { setSubmitting, resetForm }
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
        notifiers.notifySuccess(`JMeter configuration for ${jmeterFile.name} saved`);
      })
      .catch((reason) => notifiers.notifyError("Failed to save JMeter configuration", reason))
      .then(() => resetForm(values))
      .then(() => setSubmitting(false));
  };

  const toggleDisabled = (disabled: boolean) => {
    if (state.wizardState && state.wizardState.activeJMeterFile && state.wizardState.activeJMeterFile.id) {
      ApiFactory()
        .jmeter()
        .update(
          state.activeProject!.id,
          state.wizardState.activeJMeterFile.id,
          {disabled}
        )
        .then(() => {
          if (disabled) {
            dispatch(new DisableJMeterFileAction(state.wizardState!.activeJMeterFile!.id!));
            notifiers.notifyWarning(`JMeter plan "${state.wizardState!.activeJMeterFile!.name}" disabled`);
          } else {
            dispatch(new EnableJMeterFileAction(state.wizardState!.activeJMeterFile!.id!));
            notifiers.notifySuccess(`JMeter plan "${state.wizardState!.activeJMeterFile!.name}" enabled`);
          }
        });
    }
  }

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
      {...{setShowModal, onSubmit, toggleDisabled}}
      jmeterFile={state.wizardState!.activeJMeterFile}
    />}
    </>
  );
}
