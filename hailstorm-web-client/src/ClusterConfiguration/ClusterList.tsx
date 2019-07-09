import React from 'react';

export const ClusterList: React.FC = (props) => {
  return (
    <div className="panel">
      <div className="panel-heading">
        <div className="level">
          <div className="level-left">
            <div className="level-item">
              <i className="fas fa-globe-americas"></i> Clusters
            </div>
          </div>
          <div className="level-right">
            <div className="level-item">
              <a className="button is-small"><i className="far fa-edit"></i> Edit</a>
            </div>
          </div>
        </div>
      </div>
      {[
        "AWS us-east-1",
        "AWS us-west-1",
        "Bob's Datacenter"
      ].map(clusterTitle => (
        <a className="panel-block" key={clusterTitle}>
          <span className="panel-icon">
            <i className="fas fa-server" aria-hidden="true"></i>
          </span>
          {clusterTitle}
        </a>
      ))}
    </div>
  );
}
