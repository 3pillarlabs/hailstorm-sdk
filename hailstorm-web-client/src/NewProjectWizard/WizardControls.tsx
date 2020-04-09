import React from 'react';
import { ConfirmProjectSetupCancelAction, ActivateTabAction } from './actions';
import { WizardTabTypes } from "./domain";

export function CancelLink({ dispatch }: {
  dispatch: React.Dispatch<any>;
}): JSX.Element {
  return (
    <a
      className="button"
      onClick={() => dispatch(new ConfirmProjectSetupCancelAction())}
    >
      Cancel
    </a>
  );
}

export function BackLink({ dispatch, tab, disabled }: {
  dispatch: React.Dispatch<any>;
  tab: WizardTabTypes;
  disabled?: boolean;
}): JSX.Element {
  const enabled = !disabled;
  return enabled ?
    (<a className="button" onClick={() => dispatch(new ActivateTabAction(tab))}>Back</a>) :
    (<span className="button is-static is-disabled">Back</span>)
}

export function NextLink({ dispatch, tab }: {
  dispatch: React.Dispatch<any>;
  tab: WizardTabTypes;
}): JSX.Element {
  return <a className="button is-primary" onClick={() => dispatch(new ActivateTabAction(tab))}>Next</a>;
}
