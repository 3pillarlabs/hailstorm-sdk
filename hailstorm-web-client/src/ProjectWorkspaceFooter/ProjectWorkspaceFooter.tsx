import React from 'react';
import { Link } from 'react-router-dom';
import { DangerProjectSettings } from '../DangerProjectSettings';

export const ProjectWorkspaceFooter: React.FC = () => {
  return (
    <>
      <div className="tile notification">
        <Link to="/projects" className="button">Back to Projects</Link>
      </div>
      <DangerProjectSettings />
    </>
  );
}
