import React, { useState } from 'react';
import { Project } from '../domain';
import { ApiFactory } from '../api';

export interface RunningProjectsCtxProps {
  runningProjects: Project[];
  reloadRunningProjects: () => Promise<Project[]>;
};

export const RunningProjectsContext = React.createContext<RunningProjectsCtxProps>({
  runningProjects: [],
  reloadRunningProjects: async () => new Promise<Project[]>((resolve, _) => resolve([])),
});

export const RunningProjectsProvider: React.FC = (props) => {
  const [runningProjects, setRunningProjects] = useState<Project[]>([]);
  const reloadRunningProjects = async () => {
    return ApiFactory()
      .projects()
      .list()
      .then((fetchedProjects) => {
          setRunningProjects(fetchedProjects.filter((project) => project.running));
          return fetchedProjects;
      });
  }

  return (
    <RunningProjectsContext.Provider value={{runningProjects, reloadRunningProjects}}>
      {props.children}
    </RunningProjectsContext.Provider>
  );
}
