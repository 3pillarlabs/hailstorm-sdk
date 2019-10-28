import React, { useState } from 'react';
import { DataCenterCluster, Project } from '../domain';
import { ApiFactory } from '../api';
import { RemoveClusterAction } from './actions';

export function DataCenterView({
  cluster,
  activeProject,
  dispatch
}: {
  cluster: DataCenterCluster;
  dispatch?: React.Dispatch<any>;
  activeProject?: Project;
}) {
  const [disableRemove, setDisableRemove] = useState(false);

  return (
    <div className="card">
      <header className="card-header">
        <p className="card-header-title">
          <span className="icon"><i className="fas fa-network-wired"></i></span>
          {cluster.title}
        </p>
      </header>
      <div className="card-content">
        <div className="content">
          <div className="field">
            <label className="label">Username</label>
            <div className="control">
              <input
                readOnly
                type="text"
                className="input is-static has-background-light has-text-dark is-size-5"
                value={cluster.userName}
              />
            </div>
          </div>
          <div className="field">
            <label className="label">Username</label>
            <div className="control">
              <input
                readOnly
                type="text"
                className="input is-static has-background-light has-text-dark is-size-5"
                value={cluster.userName}
              />
            </div>
          </div>
          <div className="field">
            <label className="label">SSH Identity</label>
            <div className="control">
              <input
                readOnly
                type="text"
                className="input is-static has-background-light has-text-dark is-size-5"
                value={cluster.sshIdentity.name}
              />
            </div>
          </div>
          <div className="field">
            <label className="label">Machines</label>
            <div className="control">
              {cluster.machines.map((value) => (
              <div className="field" key={value}>
                <div className="control">
                  <input
                    readOnly
                    type="text"
                    className="input is-static has-background-light has-text-dark is-size-5"
                    {...{value}}
                  />
                </div>
              </div>
              ))}
            </div>
          </div>
          <div className="field">
            <label className="label">SSH Port</label>
            <div className="control">
              <input
                readOnly
                type="text"
                className="input is-static has-background-light has-text-dark is-size-5"
                value={cluster.sshPort}
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
    </div>
  )
}
