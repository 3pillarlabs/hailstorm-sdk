import React, { useState } from 'react';
import { ToggleButton } from './ToggleButton';
import { Link } from 'react-router-dom';
import { TerminateProject } from './TerminateProject';
import { DeleteProject } from './DeleteProject';

export const ProjectWorkspaceFooter: React.FC = () => {
  const [isPressed, setIsPressed] = useState(false);

  return (
    <>
      <div className="tile notification">
        <Link to="/projects" className="button">Back to Projects</Link>
      </div>
      <div className="workspace-danger">
        <article className="boundary">
          <h4 className="title is-4">
            <i className="fas fa-exclamation-triangle"></i> Dangerous Settings
          </h4>
          <p className="subtitle">Settings and actions below may result in data loss!</p>
          <p><ToggleButton {...{isPressed, setIsPressed}}>Show them</ToggleButton></p>
        </article>

        <article className={isPressed ? "message is-warning" : "message is-warning is-hidden"}>
          <TerminateProject />
        </article>
        <DeleteProject {...{isPressed}} />
      </div>
    </>
  );
}
