import React from 'react';
import { DataCenterCluster, Project } from '../domain';
import { RemoveCluster } from './RemoveCluster';
import styles from '../NewProjectWizard/NewProjectWizard.module.scss';
import { ReadOnlyField } from './ReadOnlyField';
import { ClusterViewHeader } from './ClusterViewHeader';

export function DataCenterView({
  cluster,
  activeProject,
  dispatch
}: {
  cluster: DataCenterCluster;
  dispatch?: React.Dispatch<any>;
  activeProject?: Project;
}) {

  return (
    <div className="card">
      <ClusterViewHeader
        title={cluster.title}
        icon={(<i className="fas fa-network-wired"></i>)}
      />
      <div className={`card-content${cluster.disabled ? ` ${styles.disabledContent}` : ''}`}>
        <div className="content">
          <ReadOnlyField label="Username" value={cluster.userName} />
          <ReadOnlyField label="SSH Identity" value={cluster.sshIdentity.name} />
          <div className="field">
            <label className="label">Machines</label>
            <div className="control">
              {cluster.machines.map((value) => (<ReadOnlyField {...{value}} />))}
            </div>
          </div>
          <ReadOnlyField label="SSH Port" value={cluster.sshPort || 22} />
        </div>
      </div>
      {activeProject && dispatch && (<div className="card-footer">
        <RemoveCluster {...{activeProject, cluster, dispatch}} />
      </div>)}
    </div>
  )
}
