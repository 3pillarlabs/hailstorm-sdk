import React, { useContext, useEffect } from 'react';
import { RunningProjectsContext, RunningProjectsCtxProps } from '../RunningProjectsProvider'
import { ApiFactory } from '../api';

export const RunningProjects: React.FC = () => {
  const context = useContext(RunningProjectsContext);

  useEffect(() => {
    console.debug('RunningProjects#useEffect');
    fetchRunningProjects(context);
  }, []);

  return null;
}

export async function fetchRunningProjects(context: RunningProjectsCtxProps) {
  return ApiFactory()
    .projects()
    .list()
    .then((fetchedProjects) => {
        if (context.setRunningProjects) context.setRunningProjects(fetchedProjects.filter((project) => project.running));
        return fetchedProjects;
    });
}
