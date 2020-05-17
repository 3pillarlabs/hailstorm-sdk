import React from 'react';
import styles from './LogOptions.module.scss';

export function LogOptions({
  onClear,
  onChangeScrollLimit,
  verbose,
  setVerbose
}:{
  onClear: () => void;
  onChangeScrollLimit: (value: number) => void;
  verbose: boolean;
  setVerbose: React.Dispatch<React.SetStateAction<boolean>>;
}) {

  return (
    <div className="dropdown is-right is-hoverable is-pulled-right">
      <div className="dropdown-trigger">
        <button className="button is-small" aria-haspopup="true" aria-controls="ProjectWorkSpaceLog_LogOptions">
          <span>Options</span>
          <span className="icon is-small">
            <i className="fas fa-angle-down" aria-hidden="true"></i>
          </span>
        </button>
      </div>
      <div className="dropdown-menu" id="ProjectWorkSpaceLog_LogOptions" role="menu">
        <div className="dropdown-content">
          <div className={`dropdown-item ${styles.optionBar}`}>
            <p>
              <label className="checkbox">
                <input type="checkbox" checked={verbose} onChange={() => setVerbose(!verbose)} />
                Verbose
              </label>
            </p>
          </div>
          <div className={`dropdown-item ${styles.optionBar}`}>
            <p>
              <label>Scroll limit</label>
              <div className="select">
                <select
                  onChange={(event) => onChangeScrollLimit(parseInt(event.target.value))}
                >
                  <option value={500}>500 lines</option>
                  <option value={1000}>1000 lines</option>
                  <option value={1500}>1500 lines</option>
                  <option value={2000}>2000 lines</option>
                </select>
              </div>
            </p>
          </div>
          <div className="dropdown-item">
            <p>
              <button className="button" onClick={onClear}>Clear</button>
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
