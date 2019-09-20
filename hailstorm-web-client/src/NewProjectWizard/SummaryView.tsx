import React, { useContext } from 'react';
import { AppStateContext } from '../appStateContext';
import { ReviewCompletedAction } from './actions';
import { CancelLink, BackLink } from './WizardControls';
import { WizardTabTypes } from '../store';

export const SummaryView: React.FC = () => {
  const {dispatch} = useContext(AppStateContext);

  return (
    <>
    <h3 className="title is-3">Review</h3>
    <CancelLink {...{dispatch}} />
    <BackLink {...{dispatch, tab: WizardTabTypes.Cluster}} />
    <button className="button is-success" onClick={() => dispatch(new ReviewCompletedAction())}>Done</button>
    </>
  )
}
