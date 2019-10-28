import React, { useState } from 'react';
import { Project, AmazonCluster } from '../domain';
import { RemoveClusterAction } from './actions';
import { ApiFactory } from '../api';

export function AWSView({ cluster, dispatch, activeProject }: {
  cluster: AmazonCluster;
  dispatch?: React.Dispatch<any>;
  activeProject?: Project;
}) {
  const [disableRemove, setDisableRemove] = useState(false);

  return (<div className="card">
    <header className="card-header">
      <p className="card-header-title">
        <span className="icon"><i className="fab fa-aws"></i></span>
        {cluster.title}
      </p>
    </header>
    <div className="card-content">
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
      <div className="card-footer-item">
        <button
          type="button"
          className="button is-warning"
          role="Remove Cluster"
          disabled={disableRemove}
          onClick={() => {
            setDisableRemove(true);
            ApiFactory()
              .clusters()
              .destroy(activeProject.id, cluster.id!)
              .then(() => {
                dispatch(new RemoveClusterAction(cluster));
              });
          }}
        >
          Remove
        </button>
      </div>
    </div>)}
  </div>);
}
