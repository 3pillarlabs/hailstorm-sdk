import React from 'react';
import { RemoveClusterAction } from './actions';
export function ClusterFormFooter({ dispatch, disabled }: {
  dispatch: React.Dispatch<any>;
  disabled: boolean;
}) {
  return (<div className="card-footer">
    <div className="card-footer-item">
      <button type="button" className="button is-warning" role="Remove Cluster" onClick={() => dispatch(new RemoveClusterAction())}>
        Remove
        </button>
    </div>
    <div className="card-footer-item">
      <button type="submit" className="button is-dark" disabled={disabled}>Save</button>
    </div>
  </div>);
}
