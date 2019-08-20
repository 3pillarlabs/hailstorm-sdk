import React, { useState, useEffect, useReducer } from 'react';
import { ProjectWorkspaceHeader } from '../ProjectWorkspaceHeader';
import { ProjectWorkspaceMain } from '../ProjectWorkspaceMain';
import { ProjectWorkspaceLog } from '../ProjectWorkspaceLog';
import { ProjectWorkspaceFooter } from '../ProjectWorkspaceFooter';
import { Project, InterimProjectState } from '../domain';
import { ApiFactory } from '../api';
import { Loader, LoaderSize } from '../Loader';
import { RouteComponentProps } from 'react-router';
import { reducer } from './reducers';
import { SetProjectAction, ProjectWorkspaceActions } from './actions';

export interface ProjectWorkspaceBasicProps {
  project: Project;
}

interface TProps {
  id: string;
}

export interface ActiveProjectContextProps {
  project: Project;
  dispatch: React.Dispatch<ProjectWorkspaceActions>
}

export const ActiveProjectContext = React.createContext<ActiveProjectContextProps>({
  project: {} as Project,
  dispatch: (_value) => {},
});

export const ProjectWorkspace: React.FC<RouteComponentProps<TProps>> = (props) => {
  const [project, dispatch] = useReducer(reducer, undefined);

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
  }, [props]);

  return (
    <div className="container">
    <>
    {
      project && project.id === parseInt(props.match.params.id) ?
      <ActiveProjectContext.Provider value={{project, dispatch}}>
        <ProjectWorkspaceHeader project={project} />
        <ProjectWorkspaceMain />
        <ProjectWorkspaceLog />
        <ProjectWorkspaceFooter />
        {props.children}
      </ActiveProjectContext.Provider> :
      <Loader size={LoaderSize.APP} />}
    </>
    </div>
  );
}
