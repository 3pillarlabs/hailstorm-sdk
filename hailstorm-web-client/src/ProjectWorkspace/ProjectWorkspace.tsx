import React, { useState, useEffect } from 'react';
import { ProjectWorkspaceHeader } from '../ProjectWorkspaceHeader';
import { ProjectWorkspaceMain } from '../ProjectWorkspaceMain';
import { ProjectWorkspaceLog } from '../ProjectWorkspaceLog';
import { ProjectWorkspaceFooter } from '../ProjectWorkspaceFooter';
import { Project, InterimProjectState } from '../domain';
import { ApiFactory } from '../api';
import { Loader, LoaderSize } from '../Loader';
import { RouteComponentProps } from 'react-router';
import { interimStateReducer } from './reducers';

export interface ProjectWorkspaceBasicProps {
  project: Project;
}

interface TProps {
  id: string;
}

export interface ActiveProjectContextProps {
  project: Project;
  setRunning: (endState: boolean) => void;
  setInterimState: (state: InterimProjectState | null) => void;
}

export const ActiveProjectContext = React.createContext<ActiveProjectContextProps>({
  project: {} as Project,
  setRunning: () => {},
  setInterimState: () => {}
});

export const ProjectWorkspace: React.FC<RouteComponentProps<TProps>> = (props) => {
  const [project, setProject] = useState<Project | undefined>(undefined);
  const setRunning = (endState: boolean) => {
    if (project) setProject({...project, running: endState});
  };

  const dispatch = (action: any) => {
    if (project) {
      return interimStateReducer(project, action);
    }
  };

  const setInterimState = (state: InterimProjectState | null) => {
    if (state) {
      setProject(dispatch({type: 'set', payload: state}));
    } else {
      setProject(dispatch({type: 'unset'}));
    }
  }

  useEffect(() => {
    console.debug('ProjectWorkspace#useEffect(props)');
    if (props.location.state) {
      setProject(props.location.state.project);
    } else {
      ApiFactory()
        .projects()
        .get(parseInt(props.match.params.id))
        .then((fetchedProject) => setProject(fetchedProject));
    }
  }, [props]);

  return (
    <div className="container">
    <>
    {
      project && project.id === parseInt(props.match.params.id) ?
      <ActiveProjectContext.Provider value={{project, setRunning, setInterimState}}>
        <ProjectWorkspaceHeader project={project} />
        <ProjectWorkspaceMain />
        <ProjectWorkspaceLog />
        <ProjectWorkspaceFooter></ProjectWorkspaceFooter>
        {props.children}
      </ActiveProjectContext.Provider> :
      <Loader size={LoaderSize.APP} />}
    </>
    </div>
  );
}
