import React from 'react';
import { Cluster } from '../domain';
import styles from '../NewProjectWizard/NewProjectWizard.module.scss';
import { EmptyPanel } from '../EmptyPanel';

export const ClusterList: React.FC<{
  clusters?: Cluster[];
  showEdit?: boolean;
  onSelectCluster?: (cluster: Cluster) => void;
  activeCluster?: Cluster;
  disableEdit?: boolean;
  onEdit?: () => void;
  showDisabledCluster?: boolean;
}> = ({clusters, showEdit, onSelectCluster, activeCluster, disableEdit, onEdit, showDisabledCluster}) => {

  const sortFn: (a: Cluster, b: Cluster) => number = (a, b) => {
    const aValue = a.disabled ? 1 : 0;
    const bValue = b.disabled ? 1 : 0;
    return (aValue - bValue);
  };

  let displayedClusters: Cluster[] | undefined = undefined;
  if (clusters) {
    displayedClusters = (showDisabledCluster ? clusters : clusters.filter((value) => !value.disabled)).sort(sortFn);
  }

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
              <button className="button is-small" disabled={disableEdit} onClick={onEdit}>
                <i className="far fa-edit"></i> Edit
              </button>
              )}
            </div>
          </div>
        </div>
      </div>
      {displayedClusters !== undefined && displayedClusters.length > 0 ? (
      displayedClusters.map(cluster => (
        (onSelectCluster ? (
        <a
          className={`panel-block${activeCluster && activeCluster.id === cluster.id ? " is-active": ""}`}
          key={cluster.id}
          onClick={() => onSelectCluster(cluster)}
        >
          <PanelItem {...{cluster}} />
        </a>
        ) : (
        <div className="panel-block" key={cluster.id} >
          <PanelItem {...{cluster}} />
        </div>
        ))
      ))
      ) : (
      <EmptyPanel />
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

function PanelItem({
  cluster
}: {
  cluster: Cluster
}) {
  return (
    <>
    <PanelItemIcon {...{cluster}} />
    {cluster.title}
    {cluster.disabled && (<span className={`tag is-dark ${styles.titleLabel}`}>disabled</span>)}
    </>
  );
}
