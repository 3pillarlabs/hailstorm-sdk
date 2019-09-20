import React, { useContext } from 'react';
import { AppStateContext } from '../appStateContext';
import { ClusterSetupCompletedAction } from '../NewProjectWizard/actions';
import { CancelLink, BackLink } from '../NewProjectWizard/WizardControls';
import { WizardTabTypes } from '../store';

export const ClusterConfiguration: React.FC = () => {
  const {dispatch} = useContext(AppStateContext);

  return (
    <>
    <h3 className="title is-3">Setup Clusters</h3>
    <CancelLink {...{dispatch}} />
    <BackLink {...{dispatch, tab: WizardTabTypes.JMeter}} />
    <button className="button is-primary" onClick={() => dispatch(new ClusterSetupCompletedAction())}>Next</button>
    </>
  );
}
