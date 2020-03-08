import React from 'react';
import { DataCenterCluster, Project } from '../domain';
import { RemoveCluster } from './RemoveCluster';

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
        <RemoveCluster {...{activeProject, cluster, dispatch}} />
      </div>)}
    </div>
  )
}
