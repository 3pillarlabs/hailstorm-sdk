import React, { useState, useEffect, useContext } from 'react';
import logo from '../AppLogo.png';
import { ProjectBar } from '../ProjectBar';
import { NavLink, Link, withRouter } from 'react-router-dom';
import { RunningProjectsContext } from '../RunningProjectsProvider';
import { RouteComponentProps } from 'react-router';

// Top Navigation Component
const TopNavWithouRouter: React.FC<RouteComponentProps> = ({location}) => {
  const [isBurgerActive, dispatchBurgerActive] = useState(false);
  const handleBurgerClick = (event: React.SyntheticEvent) => {
    event.currentTarget.classList.toggle("is-active");
    dispatchBurgerActive(!isBurgerActive);
  };

  const {reloadRunningProjects} = useContext(RunningProjectsContext);

  useEffect(() => {
    if (location.pathname === '/' || location.pathname === '/projects') return;
    console.debug('TopNav#useEffect');
    reloadRunningProjects();
  }, []);

  return (
    <nav className="navbar is-light" role="navigation">
      <div className="container">
        <div className="navbar-brand">
          <Link className="navbar-item" to="/">
            <span className="app-logo">
              <img src={logo} className="app-logo" alt="HAILSTORM" />
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
            <ProjectBar maxItems={5}></ProjectBar>
          </div>

          <div className="navbar-end">
            <div className="navbar-item">
              <Link className="button is-info" to="/wizard/projects/new"> New Project </Link>
            </div>
          </div>
        </div>
      </div>
    </nav>
  );
}

export const TopNav = withRouter(TopNavWithouRouter);
