import React, { useState, useEffect } from 'react';
import { ProjectWorkspaceHeader } from '../ProjectWorkspaceHeader';
import { ProjectWorkspaceMain } from '../ProjectWorkspaceMain';
import { ProjectWorkspaceLog } from '../ProjectWorkspaceLog';
import { ProjectWorkspaceFooter } from '../ProjectWorkspaceFooter';
import { Project } from '../domain';
import { ApiFactory } from '../api';
import { Loader, LoaderSize } from '../Loader';
import { RouteComponentProps } from 'react-router';

export interface ProjectWorkspaceBasicProps {
  project: Project;
}

interface TProps {
  id: string;
}

export interface ActiveProjectContextProps {
  project: Project;
  setRunning: (endState: boolean) => void;
}

export const ActiveProjectContext = React.createContext<ActiveProjectContextProps>({
  project: {} as Project,
  setRunning: () => {}
});

export const ProjectWorkspace: React.FC<RouteComponentProps<TProps>> = (props) => {
  const [project, setProject] = useState<Project | undefined>(undefined);
  const setRunning = (endState: boolean) => {
    if (project) setProject({...project, running: endState});
  };

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
      <ActiveProjectContext.Provider value={{project, setRunning}}>
        <ProjectWorkspaceHeader project={project} />
        <ProjectWorkspaceMain />
        <ProjectWorkspaceLog></ProjectWorkspaceLog>
        <ProjectWorkspaceFooter></ProjectWorkspaceFooter>
      </ActiveProjectContext.Provider> :
      <Loader size={LoaderSize.APP} />}
    </>
    </div>
  );
}
