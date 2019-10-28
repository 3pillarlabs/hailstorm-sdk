import React from 'react';
import { Cluster } from '../domain';

export const ClusterList: React.FC<{
  clusters?: Cluster[];
  showEdit?: boolean;
  onSelectCluster?: (cluster: Cluster) => void;
  activeCluster?: Cluster;
  disableEdit?: boolean;
}> = ({clusters, showEdit, onSelectCluster, activeCluster, disableEdit}) => {

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
              {showEdit && (
              <button className="button is-small" disabled={disableEdit}>
                <i className="far fa-edit"></i> Edit
              </button>
              )}
            </div>
          </div>
        </div>
      </div>
      {clusters !== undefined ? (
      clusters.map(cluster => (
        (onSelectCluster ? (
        <a
          className={`panel-block${activeCluster && activeCluster.id === cluster.id ? " is-active": ""}`}
          key={cluster.id}
          onClick={() => onSelectCluster(cluster)}
        >
          <PanelItemIcon {...{cluster}} />
          {cluster.title}
        </a>
        ) : (
        <div className="panel-block" key={cluster.id} >
          <PanelItemIcon {...{cluster}} />
          {cluster.title}
        </div>
        ))
      ))
      ) : (
      <>
      <div className="panel-block"></div>
      <div className="panel-block"></div>
      <div className="panel-block"></div>
      </>
      )}
    </div>
  );
}

function PanelItemIcon({
  cluster
}: {
  cluster: Cluster;
}) {

  return (
    <span className="panel-icon">
      <i className={cluster.type === 'AWS' ? "fab fa-aws" : "fas fa-network-wired"} aria-hidden="true"></i>
    </span>
  );
}
