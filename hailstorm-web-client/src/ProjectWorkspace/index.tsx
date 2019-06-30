import React from 'react';
import { ProjectWorkspaceHeader } from '../ProjectWorkspaceHeader';
import { ProjectWorkspaceMain } from '../ProjectWorkspaceMain';
import { ProjectWorkspaceLog } from '../ProjectWorkspaceLog';
import { ProjectWorkspaceFooter } from '../ProjectWorkspaceFooter';

export const ProjectWorkspace: React.FC = () => {
  return (
    <div className="container">
      <ProjectWorkspaceHeader></ProjectWorkspaceHeader>
      <ProjectWorkspaceMain></ProjectWorkspaceMain>
      <ProjectWorkspaceLog></ProjectWorkspaceLog>
      <ProjectWorkspaceFooter></ProjectWorkspaceFooter>
    </div>
  );
}
