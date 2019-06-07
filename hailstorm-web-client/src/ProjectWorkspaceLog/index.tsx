import React from 'react';

export const ProjectWorkspaceLog: React.FC = () => {
  return (
    <div className="columns workspace-log">
      <div className="column is-9 is-offset-3">
        <div className="panel">
          <div className="panel-heading">
            <i className="fas fa-info-circle"></i> Log
          </div>
          <div className="panel-block">
            [INFO] Starting Tests... <br/>
            [INFO] Creating Cluster in us-east-1...
          </div>
        </div>
      </div>
    </div>
  );
}
