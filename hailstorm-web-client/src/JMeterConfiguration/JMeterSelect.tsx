import React from 'react';
import { SetDefaultJMeterVersionAction } from './actions';

export function JMeterSelect({ versions, defaultVersion, dispatch }: {
  versions: string[];
  defaultVersion?: string;
  dispatch: React.Dispatch<any>;
}) {
  return (<div className="level">
    <div className="level-left">
      <div className="level-item">
        <div className="field">
          <label className="label" htmlFor="versionSelector">JMeter Version</label>
        </div>
      </div>
    </div>
    <div className="level-right">
      <div className="level-item">
        <div className="field">
          <div className="control">
            <div className={`select ${versions.length === 0 ? 'is-loading' : ''}`}>
              <select
                id="versionSelector"
                value={defaultVersion}
                onChange={(event) => dispatch(new SetDefaultJMeterVersionAction(event.target.value))}
              >
                {versions.map((value) => (<option key={value} {...{ value }}>{value}</option>))}
              </select>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>);
}
