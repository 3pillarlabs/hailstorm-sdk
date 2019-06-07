import React from 'react';

export const ProjectWorkspaceHeader: React.FC = () => {
  return (
    <div className="columns workspace-header">
      <div className="column is-four-fifths">
        <h2 className="title is-2">
          Hailstorm Basic Priming test with Digital Ocean droplets and custom JMeter
          <sup><i className="fas fa-pen"></i></sup>
        </h2>
      </div>
      <div className="column">
        <h2 className="title is-2 is-status">Running</h2>
      </div>
    </div>
  );
};
