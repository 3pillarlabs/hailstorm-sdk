import React, { useState, useEffect } from 'react';
import { ProjectWorkspaceHeader } from '../ProjectWorkspaceHeader';
import { ProjectWorkspaceMain } from '../ProjectWorkspaceMain';
import { ProjectWorkspaceLog } from '../ProjectWorkspaceLog';
import { ProjectWorkspaceFooter } from '../ProjectWorkspaceFooter';
import { Project } from '../domain';
import { ApiFactory } from '../api';
import { Loader, LoaderSize } from '../Loader';
import { RunningProjects } from '../RunningProjects';
import { RouteComponentProps } from 'react-router';

export interface ProjectWorkspaceBasicProps {
  project: Project;
}

interface TProps {
  id: string;
}

export const ProjectWorkspace: React.FC<RouteComponentProps<TProps>> = (props) => {
  const projectProp: Project = props.location && props.location.state && props.location.state.project;
  const [project, setProject] = useState<Project>({...projectProp});
  useEffect(() => {
    console.debug('ProjectWorkspace#useEffect');
    if (project && project.id === parseInt(props.match.params.id)) return;
    ApiFactory()
      .projects()
      .get(props.match.params.id)
      .then((fetchedProject) => setProject(fetchedProject));
  });

  return (
    <div className="container">
    <>
    {
      project && project.id === parseInt(props.match.params.id) ?
      <>
      <ProjectWorkspaceHeader project={project} />
      <ProjectWorkspaceMain></ProjectWorkspaceMain>
      <ProjectWorkspaceLog></ProjectWorkspaceLog>
      <ProjectWorkspaceFooter></ProjectWorkspaceFooter>
      </> : <Loader size={LoaderSize.APP} />
    }
      <RunningProjects />
    </>
    </div>
  );
}
