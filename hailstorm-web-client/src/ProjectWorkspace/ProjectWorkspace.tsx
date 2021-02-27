import React, { useEffect, useState } from 'react';
import { ProjectWorkspaceHeader } from '../ProjectWorkspaceHeader';
import { ProjectWorkspaceMain } from '../ProjectWorkspaceMain';
import { ProjectWorkspaceLog } from '../ProjectWorkspaceLog';
import { ProjectWorkspaceFooter } from '../ProjectWorkspaceFooter';
import { Project } from '../domain';
import { ApiFactory } from '../api';
import { Loader, LoaderSize } from '../Loader';
import { RouteComponentProps, Redirect } from 'react-router';
import { SetProjectAction } from './actions';
import { AppStateContext, useAppState } from '../appStateContext';
import { UnsavedChangesPrompt } from '../Modal/UnsavedChangesPrompt';
import { Link } from 'react-router-dom';
import { UnsetProjectAction } from '../NewProjectWizard/actions';

export interface ProjectWorkspaceBasicProps {
  project: Project;
}

export const ProjectWorkspace: React.FC<RouteComponentProps<{ id: string }>> = (props) => {
  const {appState, dispatch} = useAppState();
  const [showModal, setShowModal] = useState(false);
  const [handleNotFound, setHandleNotFound] = useState(false);

  useEffect(() => {
    console.debug('ProjectWorkspace#useEffect(props.match.params.id)');
    if (props.location.state) {
      dispatch(new SetProjectAction(props.location.state.project));
    } else {
      ApiFactory()
        .projects()
        .get(parseInt(props.match.params.id))
        .then((fetchedProject) => dispatch(new SetProjectAction(fetchedProject)))
        .catch((reason) => {
          if (typeof(reason) === 'object' && reason instanceof Error) setHandleNotFound(true);
        });
    }
  }, [props.match.params.id]);

  useEffect(() => {
    console.debug('ProjectWorkspace#useEffect()');
    return () => dispatch(new UnsetProjectAction());
  }, []);

  if (handleNotFound) {
    return (
      <div className="container">
        <div className="notification is-warning">
          Did not find a project at <code>{`${props.location.pathname}`}</code>. <br/><br/>
          <Link to="/projects" className="button is-dark">Back to Projects</Link>
        </div>
      </div>
    );
  }

  const project = appState.activeProject;

  return (
    <div className="container">
    {project && project.id === parseInt(props.match.params.id) ?
      <>
      <UnsavedChangesPrompt
        {...{showModal, setShowModal}}
        hasUnsavedChanges={project && project.interimState !== undefined}
        unSavedChangesDeps={[project]}
      >
        <p>
          You have operations in progress. If you navigate away from this page now, the operations will
          terminate, leaving the system in an ambigious state. You will most likely have to terminate
          the setup and start over again.
        </p>
        <p>
          <strong>Are you sure you want to navigate away from the page?</strong>
        </p>
      </UnsavedChangesPrompt>
      <ProjectWorkspaceHeader />
      <ProjectWorkspaceMain />
      <ProjectWorkspaceLog />
      <ProjectWorkspaceFooter />
      {props.children}
      </>
      :
      <Loader size={LoaderSize.APP} />}
    </div>
  );
}
