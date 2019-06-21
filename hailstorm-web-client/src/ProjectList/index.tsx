import React from 'react';

export const ProjectList: React.FC = () => {
  return (
    <div className="container">
      <h2 className="title is-2 workspace-header">Running now</h2>
      <div className="tile is-ancestor">
        <div className="tile is-3 is-parent">
          <article className="tile is-child notification is-warning">
            <p className="title is-4">Hailstorm Basic Priming test with Digital Ocean droplets and custom JMeter</p>
          </article>
        </div>
      </div>

      <h2 className="title is-2 workspace-header">Just completed</h2>
      <div className="tile is-ancestor">
        <div className="tile is-3 is-parent">
          <div className="tile is-child notification is-success">
            <p className="title is-4">Hailstorm Basic Priming</p>
          </div>
        </div>
        <div className="tile is-3 is-parent">
          <div className="tile is-child notification is-danger">
            <p className="title is-4">Acme 30 burst</p>
          </div>
        </div>
      </div>

      <h2 className="title is-2 workspace-header">Others</h2>
      <div className="tile is-ancestor">
        <div className="tile is-3 is-parent">
          <div className="tile is-child notification is-light">
            <p className="title is-4">Acme 60 Burst</p>
          </div>
        </div>
        <div className="tile is-3 is-parent">
          <div className="tile is-child notification is-light">
            <p className="title is-4">Acme 90 burst</p>
          </div>
        </div>
      </div>

    </div>
  );
}
