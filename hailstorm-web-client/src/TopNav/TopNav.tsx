import React, { useState, useEffect, useContext } from 'react';
import logo from '../AppLogo.png';
import { ProjectBar } from '../ProjectBar';
import { NavLink, Link, withRouter } from 'react-router-dom';
import { RouteComponentProps } from 'react-router';
import styles from './TopNav.module.scss';
import { AppStateContext } from '../appStateContext';
import { ApiFactory } from '../api';
import { SetRunningProjectsAction, AddRunningProjectAction, RemoveNotRunningProjectAction } from './actions';
import { ProjectSetupAction } from '../NewProjectWizard/actions';

// Top Navigation Component
const TopNavWithoutRouter: React.FC<RouteComponentProps> = ({location}) => {
  const [isBurgerActive, setBurgerActive] = useState(false);
  const {appState, dispatch} = useContext(AppStateContext);
  const handleBurgerClick = (event: React.SyntheticEvent) => {
    event.currentTarget.classList.toggle("is-active");
    setBurgerActive(!isBurgerActive);
  };

  const isLocationProjectList = location.pathname === '/' || location.pathname === '/projects';

  useEffect(() => {
    if (isLocationProjectList || appState.runningProjects.length > 0) return;

    console.debug('TopNav#useEffect');
    ApiFactory()
      .projects()
      .list()
      .then((fetchedProjects) => dispatch(new SetRunningProjectsAction(fetchedProjects.filter((p) => p.running))));
  }, []);

  useEffect(() => {
    if (!appState.activeProject) return;

    console.debug('TopNav#useEffect(appState.activeProject)');
    if (appState.activeProject!.running && appState.runningProjects.find((p) => p.id === appState.activeProject!.id) === undefined) {
      dispatch(new AddRunningProjectAction(appState.activeProject!));
    }

    if (!appState.activeProject!.running && appState.runningProjects.find((p) => p.id === appState.activeProject!.id)) {
      dispatch(new RemoveNotRunningProjectAction(appState.activeProject!));
    }
  }, [appState.activeProject]);

  return (
    <nav className="navbar is-light" role="navigation">
      <div className="container">
        <div className="navbar-brand">
          <Link className="navbar-item" to="/">
            <span className={`${styles.appLogo}`}>
              <img src={logo} className={`${styles.appLogo}`} alt="HAILSTORM" />
            </span>
          </Link>

          <a
            role="button"
            className="navbar-burger burger"
            aria-label="menu"
            aria-expanded="false"
            data-target="navbar-main"
            onClick={handleBurgerClick}
          >
            <span aria-hidden="true" />
            <span aria-hidden="true" />
            <span aria-hidden="true" />
          </a>
        </div>

        <div className={`navbar-menu${isBurgerActive ? ' is-active': ''}`}>
          <div className="navbar-start">
            <NavLink to="/projects" className="navbar-item" activeClassName="is-active" exact={true}>
              <h2>All Projects</h2>
            </NavLink>
          </div>

          {!isLocationProjectList ? (
          <div className={`navbar-start ${styles.projectBar}`}>
            <div className="has-text-info navbar-item">Running now</div>
            <ProjectBar maxItems={5} runningProjects={appState.runningProjects} />
          </div>
          ) : null}

          <div className="navbar-end">
            <div className="navbar-item">
            {appState.wizardState !== undefined ? (
              <button className="button is-info" disabled={true}>New Project</button>
            ) : (
              <Link
                className="button is-info"
                to="/wizard/projects/new"
                onClick={() => dispatch(new ProjectSetupAction())}
              >
                New Project
              </Link>
            )}
            </div>
          </div>
        </div>
      </div>
    </nav>
  );
}

export const TopNav = withRouter(TopNavWithoutRouter);
