import React from 'react';
import { Project, AmazonCluster } from '../domain';
import { RemoveCluster } from './RemoveCluster';
import styles from './ClusterConfiguration.module.scss';

export function AWSView({ cluster, dispatch, activeProject }: {
  cluster: AmazonCluster;
  dispatch?: React.Dispatch<any>;
  activeProject?: Project;
}) {

  return (<div className="card">
    <header className="card-header">
      <p className="card-header-title">
        <span className="icon"><i className="fab fa-aws"></i></span>
        {cluster.title}
      </p>
    </header>
    <div className={`card-content${cluster.disabled ? ` ${styles.disabledContent}` : ''}`}>
      <div className="content">
        <div className="field">
          <label className="label">AWS Access Key</label>
          <div className="control">
            <input
              readOnly
              type="text"
              className="input is-static has-background-light has-text-dark is-size-5"
              value={cluster.accessKey}
            />
          </div>
        </div>
        <div className="field">
          <label className="label">VPC Subnet</label>
          <div className="control">
            <input
              readOnly
              type="text"
              className="input is-static has-background-light has-text-dark is-size-5"
              value={cluster.vpcSubnetId}
            />
          </div>
        </div>
        <div className="field">
          <label className="label">AWS Region</label>
          <div className="control">
            <input
              readOnly
              type="text"
              className="input is-static has-background-light has-text-dark is-size-5"
              value={cluster.region}
            />
          </div>
        </div>
        <div className="field">
          <label className="label">AWS Instance Type</label>
          <div className="control">
            <input
              readOnly
              type="text"
              className="input is-static has-background-light has-text-dark is-size-5"
              value={cluster.instanceType}
            />
          </div>
        </div>
        <div className="field">
          <label className="label">Max. Users / Instance</label>
          <div className="control">
            <input
              readOnly
              type="text"
              className="input is-static has-background-light has-text-dark is-size-5"
              value={cluster.maxThreadsByInstance}
            />
          </div>
        </div>
      </div>
    </div>
    {activeProject && dispatch && (<div className="card-footer">
      <RemoveCluster {...{activeProject, cluster, dispatch}} />
    </div>)}
  </div>);
}
