import React from 'react';
import { NewProjectWizardState } from "../NewProjectWizard/domain";
import { JMeterPlanList } from '../JMeterPlanList';
import styles from '../NewProjectWizard/NewProjectWizard.module.scss';
import { SelectJMeterFileAction } from './actions';
import { ActiveFileDetail } from './ActiveFileDetail';
export function StepContent({ dispatch, state, setShowModal, setUploadAborted, disableAbort }: {
  dispatch: React.Dispatch<any>;
  state: NewProjectWizardState;
  setShowModal: React.Dispatch<React.SetStateAction<boolean>>;
  setUploadAborted: React.Dispatch<React.SetStateAction<boolean>>;
  disableAbort: boolean;
}) {
  return (<div className={`columns ${styles.stepContent}`}>
    <div className="column is-two-fifths">
      <JMeterPlanList onSelect={(file) => dispatch(new SelectJMeterFileAction(file))} jmeter={state.activeProject!.jmeter} activeFile={state.wizardState!.activeJMeterFile} />
    </div>

    <div className="column is-three-fifths">
      <ActiveFileDetail {...{ state, dispatch, setShowModal, setUploadAborted, disableAbort }} />
    </div>
  </div>);
}
