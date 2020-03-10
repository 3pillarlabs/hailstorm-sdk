import React, { useState } from 'react';
import { ToggleButton } from './ToggleButton';
import { TerminateProject } from './TerminateProject';
import { DeleteProject } from './DeleteProject';

export function DangerProjectSettings({
  noTerminate
}: {
  noTerminate?: boolean;
}) {
  const [isPressed, setIsPressed] = useState(false);

  return (
    <div className="workspace-danger">
      <article className="boundary">
        <h4 className="title is-4">
          <i className="fas fa-exclamation-triangle"></i> Dangerous Settings
        </h4>
        <p className="subtitle">Settings and actions below may result in data loss!</p>
        <p><ToggleButton {...{isPressed, setIsPressed}}>{!isPressed ? 'Show them' : 'Hide them'}</ToggleButton></p>
      </article>

      {!noTerminate && (
      <article className={isPressed ? "message is-warning" : "message is-warning is-hidden"}>
        <TerminateProject />
      </article>
      )}
      <article className={isPressed ? "message is-danger" : "message is-danger is-hidden"}>
        <DeleteProject />
      </article>
    </div>
  );
}
