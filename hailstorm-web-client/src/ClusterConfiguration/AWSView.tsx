import React, { useEffect, useState } from 'react';
import { Project, AmazonCluster } from '../domain';
import { RemoveCluster } from './RemoveCluster';
import styles from './ClusterConfiguration.module.scss';
import { ReadOnlyField } from './ReadOnlyField';
import { ClusterViewHeader } from './ClusterViewHeader';
import { MaxUsersByInstance } from './AWSInstanceChoice';
import { ApiFactory } from '../api';
import { UpdateClusterAction } from './actions';

export function AWSView({ cluster, dispatch, activeProject }: {
  cluster: AmazonCluster;
  dispatch?: React.Dispatch<any>;
  activeProject?: Project;
}) {
  const [disabledUpdate, setDisabledUpdate] = useState<boolean>(false);
  const [maxThreadsByInstance, setMaxThreadsByInstance] = useState<number>();
  useEffect(() => {
    console.debug("AWSView#useEffect()");
    setMaxThreadsByInstance(cluster.maxThreadsByInstance);
  }, [cluster]);

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
          {cluster.disabled || !dispatch ? (
            <ReadOnlyField label="Max. Users / Instance" value={cluster.maxThreadsByInstance} />
          ) : (
            <MaxUsersByInstance
              value={maxThreadsByInstance}
              onChange={(event: {target: {value: string}}) => {
                setMaxThreadsByInstance(event.target.value as unknown as number);
              }}
            />
          )}
        </div>
      </div>
      {activeProject && dispatch && (<div className="card-footer">
        <RemoveCluster {...{activeProject, cluster, dispatch}} />
        {!cluster.disabled && (
          <div className="card-footer-item">
          <button
            type="button"
            className="button is-warning"
            role="Update Cluster"
            disabled={disabledUpdate}
            onClick={async () => {
              setDisabledUpdate(true);
              try {
                const updatedCluster = await ApiFactory().clusters().update(
                  activeProject.id,
                  cluster.id!,
                  {maxThreadsByInstance}
                );
                dispatch(new UpdateClusterAction(updatedCluster));
              } catch (error) {
                console.error(error);
              } finally {
                setDisabledUpdate(false);
              }
            }}
          >
            Update
          </button>
          </div>
        )}
      </div>)}
    </div>
  );
}
