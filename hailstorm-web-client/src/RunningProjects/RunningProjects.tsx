import React, { useContext, useEffect } from 'react';
import { RunningProjectsContext } from '../RunningProjectsProvider'

export const RunningProjects: React.FC = () => {
  const {reloadRunningProjects} = useContext(RunningProjectsContext);

  useEffect(() => {
    console.debug('RunningProjects#useEffect');
    reloadRunningProjects();
  }, []);

  return null;
}
