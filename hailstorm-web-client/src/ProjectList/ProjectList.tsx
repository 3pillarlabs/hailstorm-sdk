import React, { useState, useEffect, SetStateAction, useContext } from 'react';
import { Loader, LoaderSize } from '../Loader';
import { Project, ExecutionCycleStatus } from '../domain';
import styles from './ProjectList.module.scss';
import { Link } from 'react-router-dom';
import { ApiFactory } from '../api';
import { AppStateContext } from '../appStateContext';
import { SetRunningProjectsAction } from '../TopNav/actions';

function projectItem(project: Project): JSX.Element {
  let notificationQualifier = 'is-light';
  if (project.running) {
    notificationQualifier = 'is-warning';

  } else if (project.recentExecutionCycle) {
    switch (project.recentExecutionCycle.status) {
      case ExecutionCycleStatus.STOPPED:
        notificationQualifier = 'is-success';
        break;

      case ExecutionCycleStatus.ABORTED:
        notificationQualifier = 'is-warning';
        break;

      case ExecutionCycleStatus.FAILED:
        notificationQualifier = 'is-danger';
        break;

      default:
        break;
    }
  }

  return (
    <div className="tile is-3 is-parent" key={project.id}>
      <article className={`tile is-child notification ${notificationQualifier} ${styles.tileCard}`}>
        <p className="title is-4">
          <Link to={{pathname: `/projects/${project.id}`, state: { project }}}>
            {project.title}
          </Link>
        </p>
      </article>
    </div>
  );
}

export const ProjectList: React.FC = () => {
  const [loading, setLoading] = useState(true);
  const [projects, setProjects] = useState<Project[]>([]);
  const {dispatch} = useContext(AppStateContext);
  useEffect(() => {
    if (loading) {
      console.debug('ProjectList#useEffect');
      ApiFactory()
        .projects()
        .list()
        .then((fetchedProjects) => {
          setProjects(fetchedProjects);
          dispatch(new SetRunningProjectsAction(fetchedProjects.filter((p) => p.running)));
        })
        .then(() => setLoading(false))
        .catch((reason) => console.error(reason));
    }
  }, []);

  return (
    loading ?
    <Loader size={LoaderSize.APP} /> :
    <div className="container">
      <h2 className="title is-2 workspace-header">Running now</h2>
      <div className={`tile is-ancestor ${styles.wrap} ${styles.nowRunning}`}>
        {projects.filter((p) => p.running).map(projectItem)}
      </div>

      <h2 className="title is-2 workspace-header">Just completed</h2>
      <div className={`tile is-ancestor ${styles.wrap} ${styles.justCompleted}`}>
        {projects.filter((project) => !project.running && project.recentExecutionCycle).map(projectItem)}
      </div>

      <h2 className="title is-2 workspace-header">All</h2>
      <div className={`tile is-ancestor ${styles.wrap} ${styles.allProjects}`}>
        {projects.map(projectItem)}
      </div>
    </div>
  );
}
