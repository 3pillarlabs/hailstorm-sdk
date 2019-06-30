import React, { useState } from 'react';
import { Project } from '../domain';

export interface RunningProjectsCtxProps {
  runningProjects: Project[];
  setRunningProjects: React.Dispatch<React.SetStateAction<Project[]>> | undefined;
  fetchAttempted: boolean;
  setFetchAttempted: React.Dispatch<React.SetStateAction<boolean>> | undefined;
};

export const RunningProjectsContext = React.createContext<RunningProjectsCtxProps>({
  runningProjects: [],
  setRunningProjects: undefined,
  fetchAttempted: false,
  setFetchAttempted: undefined
});

export const RunningProjectsProvider: React.FC = (props) => {
  const [runningProjects, setRunningProjects] = useState<Project[]>([]);
  const [fetchAttempted, setFetchAttempted] = useState(false);
  return (
    <RunningProjectsContext.Provider value={{runningProjects, setRunningProjects, fetchAttempted, setFetchAttempted}}>
      {props.children}
    </RunningProjectsContext.Provider>
  );
}
