import React from 'react';
import { Project, AmazonCluster } from '../domain';
import { RemoveCluster } from './RemoveCluster';
import styles from './ClusterConfiguration.module.scss';
import { ReadOnlyField } from './ReadOnlyField';
import { ClusterViewHeader } from './ClusterViewHeader';

export function AWSView({ cluster, dispatch, activeProject }: {
  cluster: AmazonCluster;
  dispatch?: React.Dispatch<any>;
  activeProject?: Project;
}) {

  return (
    <div className="card">
      <ClusterViewHeader
        title={cluster.title}
        icon={(<i className="fab fa-aws"></i>)}
      />
      <div className={`card-content${cluster.disabled ? ` ${styles.disabledContent}` : ''}`}>
        <div className="content">
          <ReadOnlyField label="AWS Access Key" value={cluster.accessKey} />
          <ReadOnlyField label="VPC Subnet" value={cluster.vpcSubnetId} />
          <ReadOnlyField label="AWS Region" value={cluster.region} />
          <ReadOnlyField label="AWS Instance Type" value={cluster.instanceType} />
          <ReadOnlyField label="Max. Users / Instance" value={cluster.maxThreadsByInstance} />
        </div>
      </div>
      {activeProject && dispatch && (<div className="card-footer">
        <RemoveCluster {...{activeProject, cluster, dispatch}} />
      </div>)}
    </div>
  );
}
