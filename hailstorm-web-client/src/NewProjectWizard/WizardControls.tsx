import React from 'react';
import { ConfirmProjectSetupCancelAction, ActivateTabAction } from './actions';
import { WizardTabTypes } from '../store';

export function CancelLink({ dispatch }: {
  dispatch: React.Dispatch<any>;
}): JSX.Element {
  return <a className="button" onClick={() => dispatch(new ConfirmProjectSetupCancelAction())}>Cancel</a>;
}

export function BackLink({ dispatch, tab }: {
  dispatch: React.Dispatch<any>;
  tab: WizardTabTypes;
}): JSX.Element {
  return <a className="button" onClick={() => dispatch(new ActivateTabAction(tab))}>Back</a>
}

export function NextLink({ dispatch, tab }: {
  dispatch: React.Dispatch<any>;
  tab: WizardTabTypes;
}): JSX.Element {
  return <a className="button is-primary" onClick={() => dispatch(new ActivateTabAction(tab))}>Next</a>;
}
