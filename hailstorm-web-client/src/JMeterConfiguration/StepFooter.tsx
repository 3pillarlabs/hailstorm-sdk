import React from 'react';
import { JMeterSetupCompletedAction } from '../NewProjectWizard/actions';
import { CancelLink, BackLink } from '../NewProjectWizard/WizardControls';
import { WizardTabTypes, NewProjectWizardState } from "../NewProjectWizard/domain";
import { isBackDisabled, isNextDisabled } from './JMeterConfiguration';
export function StepFooter({ dispatch, state, }: {
  dispatch: React.Dispatch<any>;
  state: NewProjectWizardState;
}) {
  return (<div className="level">
    <div className="level-left">
      <div className="level-item">
        <CancelLink {...{ dispatch }} />
      </div>
      <div className="level-item">
        <BackLink {...{ dispatch, tab: WizardTabTypes.Project }} disabled={isBackDisabled(state)} />
      </div>
    </div>
    <div className="level-right">
      <div className="level-item">
        <button className="button is-primary" onClick={() => dispatch(new JMeterSetupCompletedAction())} disabled={isNextDisabled(state)}>
          Next
          </button>
      </div>
    </div>
  </div>);
}
