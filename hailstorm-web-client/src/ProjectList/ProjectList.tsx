import React, { useState, useEffect, useContext } from 'react';
import { format, differenceInHours, differenceInMinutes, differenceInSeconds } from 'date-fns';
import { Loader, LoaderSize } from '../Loader';
import { Project, ExecutionCycleStatus } from '../domain';
import styles from './ProjectList.module.scss';
import { Link, Redirect } from 'react-router-dom';
import { ApiFactory } from '../api';
import { AppStateContext } from '../appStateContext';
import { SetRunningProjectsAction } from '../TopNav/actions';
import { History } from 'history';
import { WizardTabTypes } from '../NewProjectWizard/domain';
import { ProjectSetupAction } from '../NewProjectWizard/actions';
import { useNotifications } from '../app-notifications';

const RECENT_MINUTES = 60;
const RETRY_INTERVAL_MS = 5000;
const MAX_RETRY_ATTEMPTS = 3;

function runningTime(now: Date, then: Date) {
  let diff = differenceInHours(now, then);
  let unit = 'h';
  if (diff < 1) {
    diff = differenceInMinutes(now, then);
    unit = 'm'
  }

  if (diff < 1) {
    diff = differenceInSeconds(now, then);
    unit = 's'
  }

  return `${diff} ${unit}`;
}

function projectItem(project: Project): JSX.Element {
  let notificationQualifier = 'is-light';
  let tagText = project.incomplete ? 'incomplete' : 'never run';
  const stats: {[K: string]: any}[] = [];
  const now = new Date();

  if (project.running) {
    notificationQualifier = 'is-warning';
    tagText = 'running';
    stats.push(
      { started: format(project.currentExecutionCycle!.startedAt, 'MM/dd HH:mm') },
      { running: runningTime(now, project.currentExecutionCycle!.startedAt) },
      { threads: project.currentExecutionCycle!.threadsCount }
    );
  } else if (project.lastExecutionCycle && !project.incomplete) {
    stats.push(
      { started: format(project.lastExecutionCycle!.startedAt, 'MM/dd HH:mm') },
      { duration: runningTime(project.lastExecutionCycle.stoppedAt!, project.lastExecutionCycle!.startedAt) },
      { threads: project.lastExecutionCycle!.threadsCount }
    );


    switch (project.lastExecutionCycle.status) {
      case ExecutionCycleStatus.STOPPED:
        notificationQualifier = 'is-success';
        tagText = 'stopped';
        break;

      case ExecutionCycleStatus.ABORTED:
        notificationQualifier = 'is-warning';
        tagText = 'aborted';
        break;

      case ExecutionCycleStatus.FAILED:
        notificationQualifier = 'is-danger';
        tagText = 'failed';
        break;

      default:
        break;
    }
  }

  let linkTo: History.LocationDescriptor<{project: Project, activeTab?: WizardTabTypes}>;
  if (project.incomplete) {
    linkTo = {pathname: `/wizard/projects/${project.id}`, state: {project, activeTab: WizardTabTypes.Project}};
  } else {
    linkTo = {pathname: `/projects/${project.id}`, state: {project}};
  }

  return (
    <div className="tile is-3 is-parent" key={project.id}>
      <div className="tile is-child ">
        <div className="card">
          <header className="card-header">
            <p className="card-header-title">
              <Link to={linkTo} className="has-text-info">
                {project.title}
              </Link>
            </p>
            <Link to={linkTo} className="card-header-icon">
              <span className={`tag ${notificationQualifier}`}>{tagText}</span>
            </Link>
          </header>
          {stats.length > 0 && (<div className="card-content">
            <div className="content">
              <div className="level">
              {stats.map((stat) => (
                <div className="level-item has-text-centered" key={Object.keys(stat)[0]}>
                  <div>
                    <p className="heading">{Object.keys(stat)[0]}</p>
                    <p className="title is-6">{Object.values(stat)[0]}</p>
                  </div>
                </div>
              ))}
              </div>
            </div>
          </div>)}
          <footer className="card-footer">
            <Link to={linkTo} className={`card-footer-item`}>
              Open
            </Link>
          </footer>
        </div>
      </div>
    </div>
  );
}

export const ProjectList: React.FC<{
  loadRetryInterval?: number;
  maxLoadRetries?: number;
}> = ({
  loadRetryInterval = RETRY_INTERVAL_MS,
  maxLoadRetries = MAX_RETRY_ATTEMPTS
}) => {
  const [loading, setLoading] = useState(true);
  const [projects, setProjects] = useState<Project[]>([]);
  const [fetchTriesCount, setFetchTriesCount] = useState(0);
  const {dispatch} = useContext(AppStateContext);
  const {notifyError, notifyWarning, notifyInfo} = useNotifications();

  useEffect(() => {
    console.debug(`ProjectList#useEffect(fetchTriesCount: ${fetchTriesCount})`);
    if (loading) {
      ApiFactory()
        .projects()
        .list()
        .then((fetchedProjects) => {
          setProjects(fetchedProjects);
          dispatch(new SetRunningProjectsAction(fetchedProjects.filter((p) => p.running)));
          if (fetchedProjects.length === 0) {
            notifyInfo(`You have no projects. Start by setting one up.`);
            dispatch(new ProjectSetupAction());
          }

          setLoading(false);
        })
        .catch((reason) => {
          if (fetchTriesCount < maxLoadRetries) {
            notifyWarning(`Loading projects failed, trying again in a few seconds`);
            setTimeout(() => {
              setFetchTriesCount(fetchTriesCount + 1);
            }, loadRetryInterval);
          } else {
            notifyError(`Failed to fetch project list`, reason);
          }
        });
    }
  }, [fetchTriesCount]);

  if (loading) return (<Loader size={LoaderSize.APP} />);

  if (projects.length === 0) return (<Redirect to="/wizard/projects/new" />);

  const running = projects.filter((p) => p.running);
  const justCompleted = projects.filter((project) => (
    !project.running &&
    project.lastExecutionCycle &&
    differenceInMinutes(Date.now(), project.lastExecutionCycle.stoppedAt!) <= RECENT_MINUTES
  ));

  const others = projects.filter((project) => (
    !running.includes(project) &&
    !justCompleted.includes(project)
  ));

  return (
    <div className="container">
      <SectionWithItems items={running} styleLabel="running" title="Running now" />
      <SectionWithItems items={justCompleted} styleLabel="justCompleted" title="Just completed" />
      <SectionWithItems items={others} styleLabel="others" title="Others" />
    </div>
  );
}

function SectionWithItems({items, styleLabel, title}: {items: Project[], styleLabel: string, title: string}) {
  if (items.length === 0) return null;

  return(
    <>
    <h3 className="title is-3">{title}</h3>
    <div className={`tile is-ancestor ${styles.wrap} ${styles[styleLabel]}`}>
      {items.map(projectItem)}
    </div>
    </>
  )
}
