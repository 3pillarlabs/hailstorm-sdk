import React, { useState } from 'react';
import logo from '../AppLogo.png';
import { ProjectBar } from '../ProjectBar';

// Top Navigation Component
export const TopNav: React.FC = () => {
  const [isBurgerActive, dispatchBurgerActive] = useState(false);
  const handleBurgerClick = (event: React.SyntheticEvent) => {
    event.currentTarget.classList.toggle("is-active");
    dispatchBurgerActive(!isBurgerActive);
  };

  return (
    <nav className="navbar is-light" role="navigation">
      <div className="container">
        <div className="navbar-brand">
          <a className="navbar-item" href="/projects">
            <span className="app-logo">
              <img src={logo} className="app-logo" alt="HAILSTORM" />
            </span>
          </a>

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
            <a className="navbar-item">
              <h2>All Projects</h2>
            </a>
            <ProjectBar maxColumns={5}></ProjectBar>
          </div>

          <div className="navbar-end">
            <div className="navbar-item">
              <a className="button is-link"> New Project </a>
            </div>
          </div>
        </div>
      </div>
    </nav>
  );
}
