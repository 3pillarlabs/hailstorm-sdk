import React, { useState, useEffect, useContext } from 'react';
import { ProjectServiceFactory } from '../ProjectService';
import { Loader, LoaderSize } from '../Loader';
import { Project, ExecutionCycleStatus } from '../domain';
import { RunningProjectsContext } from '../RunningProjectsProvider';
import styles from './ProjectList.module.scss';

function projectItem(project: Project): JSX.Element {
  let notificationQualifier = 'is-light';
  if (project.running) notificationQualifier = 'is-warning';
  if (project.recentExecutionCycle) {
    switch (project.recentExecutionCycle.status) {
      case ExecutionCycleStatus.STOPPED:
        notificationQualifier = 'is-success';
        break;

      case ExecutionCycleStatus.ABORTED:
        notificationQualifier = 'is-warning';

      case ExecutionCycleStatus.FAILED:
        notificationQualifier = 'is-danger';
      default:
        break;
    }
  }
  return (
    <div className="tile is-3 is-parent" key={project.id}>
      <article className={`tile is-child notification ${notificationQualifier}`}>
        <p className="title is-4">{project.title}</p>
      </article>
    </div>
  );
}

export const ProjectList: React.FC = () => {
  const [loading, setLoading] = useState(true);
  const [projects, setProjects] = useState<Project[]>([]);
  const {runningProjects, setRunningProjects, fetchAttempted, setFetchAttempted} = useContext(RunningProjectsContext);
  useEffect(() => {
    if (loading) {
      if (!fetchAttempted && setFetchAttempted) setFetchAttempted(true);
      ProjectServiceFactory()
        .list()
        .then((fetchedProjects) => {
          setProjects(fetchedProjects);
          if (!fetchAttempted && setRunningProjects) setRunningProjects(fetchedProjects.filter((project) => project.running));
        })
        .then(() => setLoading(false));
    }
  });

  return (
    loading ?
    <Loader size={LoaderSize.APP} /> :
    <div className="container">
      <h2 className="title is-2 workspace-header">Running now</h2>
      <div className={`tile is-ancestor ${styles.wrap}`}>
        {runningProjects.map((project) => projectItem(project))}
      </div>

      <h2 className="title is-2 workspace-header">Just completed</h2>
      <div className={`tile is-ancestor ${styles.wrap}`}>
        {projects.filter((project) => project.recentExecutionCycle).map((project) => projectItem(project)) }
      </div>

      <h2 className="title is-2 workspace-header">All</h2>
      <div className={`tile is-ancestor ${styles.wrap}`}>
        {projects.map((project) => projectItem(project)) }
      </div>
    </div>
  );
}
