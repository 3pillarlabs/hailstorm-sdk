import React, { useContext, useEffect } from 'react';
import { RunningProjectsContext } from '../RunningProjectsProvider'
import { ProjectServiceFactory } from '../ProjectService';

export const RunningProjects: React.FC = () => {
  const {setRunningProjects, fetchAttempted, setFetchAttempted} = useContext(RunningProjectsContext);
  useEffect(() => {
    if (!fetchAttempted && setFetchAttempted) setFetchAttempted(true);
    ProjectServiceFactory()
      .list()
      .then((fetchedProjects) => {
        if (!fetchAttempted && setRunningProjects) setRunningProjects(fetchedProjects.filter((project) => project.running));
      });
  });

  return null;
}
