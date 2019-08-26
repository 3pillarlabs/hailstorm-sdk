import React, { useEffect, useContext } from 'react';
import { ProjectWorkspaceHeader } from '../ProjectWorkspaceHeader';
import { ProjectWorkspaceMain } from '../ProjectWorkspaceMain';
import { ProjectWorkspaceLog } from '../ProjectWorkspaceLog';
import { ProjectWorkspaceFooter } from '../ProjectWorkspaceFooter';
import { Project } from '../domain';
import { ApiFactory } from '../api';
import { Loader, LoaderSize } from '../Loader';
import { RouteComponentProps } from 'react-router';
import { SetProjectAction } from './actions';
import { AppStateContext } from '../appStateContext';

export interface ProjectWorkspaceBasicProps {
  project: Project;
}

export const ProjectWorkspace: React.FC<RouteComponentProps<{ id: string }>> = (props) => {
  const {appState, dispatch} = useContext(AppStateContext);
  useEffect(() => {
    console.debug('ProjectWorkspace#useEffect(props)');
    if (props.location.state) {
      dispatch(new SetProjectAction(props.location.state.project));
    } else {
      ApiFactory()
        .projects()
        .get(parseInt(props.match.params.id))
        .then((fetchedProject) => dispatch(new SetProjectAction(fetchedProject)));
    }
  }, [props.match.params.id]);

  const project = appState.activeProject;
  return (
    <div className="container">
    <>
    {
      project && project.id === parseInt(props.match.params.id) ?
      <>
      <ProjectWorkspaceHeader project={project} />
      <ProjectWorkspaceMain />
      <ProjectWorkspaceLog />
      <ProjectWorkspaceFooter />
      {props.children}
      </>
      :
      <Loader size={LoaderSize.APP} />}
    </>
    </div>
  );
}
