import React, { useContext } from 'react';
import { AppStateContext } from '../appStateContext';
import { JMeterSetupCompletedAction } from '../NewProjectWizard/actions';
import { CancelLink, BackLink } from '../NewProjectWizard/WizardControls';
import { WizardTabTypes } from '../store';

export const JMeterConfiguration: React.FC = () => {
  const {dispatch} = useContext(AppStateContext);

  return (
    <>
    <h3 className="title is-3">Setup JMeter</h3>
    <CancelLink {...{dispatch}} />
    <BackLink {...{dispatch, tab: WizardTabTypes.Project}} />
    <button className="button is-primary" onClick={() => dispatch(new JMeterSetupCompletedAction())}>Next</button>
    </>
  );
}
