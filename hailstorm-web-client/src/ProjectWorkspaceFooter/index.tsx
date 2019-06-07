import React, { useState } from 'react';
import { ToggleButton } from './ToggleButton';

export const ProjectWorkspaceFooter: React.FC = () => {
  const [isPressed, dispatch] = useState(false);

  return (
    <>
      <div className="tile notification">
        <a className="button">Back to Projects</a>
      </div>
      <div className="workspace-danger">
        <article className="boundary">
          <h4 className="title is-4">
            <i className="fas fa-exclamation-triangle"></i> Dangerous Settings
          </h4>
          <p className="subtitle">Settings and actions below may result in data loss!</p>
          <p><ToggleButton isPressed={isPressed} dispatch={dispatch}>Show them</ToggleButton></p>
        </article>

        <article className={isPressed ? "message is-danger" : "message is-danger is-hidden"}>
          <div className="message-body">
            <div className="columns">
              <div className="column is-3">
                <button className="button is-danger">
                  <i className="fas fa-trash"></i>&nbsp; Delete this project
                </button>
              </div>
              <div className="column is-9">
                <article>
                  <p>
                    If you delete this project, you will not be able to run the tests within. Please ensure:
                  </p>
                  <ul>
                    <li key="line-1">Data you need is exported.</li>
                    <li key="line-2">There are no on-going operations.</li>
                    <li key="line-3">The setup has been terminated.</li>
                  </ul>
                </article>
              </div>
            </div>
          </div>
        </article>
      </div>
    </>
  );
}
