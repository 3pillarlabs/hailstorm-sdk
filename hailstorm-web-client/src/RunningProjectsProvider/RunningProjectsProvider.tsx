import React, { useState } from 'react';
import { Project } from '../domain';

export interface RunningProjectsCtxProps {
  runningProjects: Project[];
  setRunningProjects: React.Dispatch<React.SetStateAction<Project[]>> | undefined;
};

export const RunningProjectsContext = React.createContext<RunningProjectsCtxProps>({
  runningProjects: [],
  setRunningProjects: undefined
});

export const RunningProjectsProvider: React.FC = (props) => {
  const [runningProjects, setRunningProjects] = useState<Project[]>([]);
  return (
    <RunningProjectsContext.Provider value={{runningProjects, setRunningProjects}}>
      {props.children}
    </RunningProjectsContext.Provider>
  );
}
