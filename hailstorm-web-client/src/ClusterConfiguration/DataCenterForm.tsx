import React, { useState } from 'react';
import { Formik, Form, Field, ErrorMessage } from 'formik';
import { FileUpload } from '../FileUpload/FileUpload';
import { MachineSet } from './MachineSet';
import { FileServer } from '../FileUpload/fileServer';
import { ApiFactory } from '../api';
import { Project, DataCenterCluster } from '../domain';
import { RemoveClusterAction, SaveClusterAction } from './actions';

export function DataCenterForm({
  dispatch,
  activeProject
}: {
  dispatch: React.Dispatch<any>;
  activeProject: Project;
}) {
  const [pemFile, setPemFile] = useState<File>();
  const [machines, setMachines] = useState<string[]>([]);
  const [machineErrors, setMachineErrors] = useState<{[K: string]: string}>();

  const onSubmit = async ({
    userName,
    sshPort,
    title,
  }: {
    title: string;
    userName: string;
    sshPort: number;
  }) => {
    return FileServer
      .sendFile(pemFile!)
      .then(async () => {
        const attrs: DataCenterCluster = {
          userName,
          sshPort,
          title,
          machines,
          sshIdentity: { name: pemFile!.name },
          type: 'DataCenter',
        };

        const data = await ApiFactory().clusters().create(activeProject.id, attrs);
        dispatch(new SaveClusterAction(data));
        return data;
      });
  };

  return (
    <div className="card">
      <div className="card-header">
        <div className="card-header-title">
          <span className="icon"><i className="fas fa-network-wired"></i></span>
          Create a new cluster in your Data Center
        </div>
      </div>
      <Formik
        isInitialValid={false}
        initialValues={{
          title: '',
          userName: '',
          sshPort: 22,
          pemFile: undefined,
          machines: [],
        }}
        validate={({title, userName, sshPort}) => {
          const errors: {[k: string]: string} = {};
          if (title.trim() === '') {
            errors.title = "Title can't be blank";
          }

          if (userName.trim() === '') {
            errors.userName = "Username can't be blank";
          }

          if (sshPort.toString().trim() !== '' && (sshPort <= 0 || sshPort > 65535 || !sshPort.toString().match(/^\d+$/))) {
            errors.sshPort = 'SSH port must be within 0-65535';
          }

          if (pemFile === undefined) {
            errors.pemFile = 'An SSH identity (private key) file is needed to connect to machines';
          }

          if (machines.length === 0) {
            errors.machines = 'At least one machine is needed for load generation';
          }

          return errors;
        }}
        onSubmit={({title, userName, sshPort}, {setSubmitting, setFieldError}) => {
          setSubmitting(true);
          onSubmit({userName, sshPort, title})
            .catch((reason) => {
              if (typeof(reason) === 'object' && Object.keys(reason).includes('validationErrors')) {
                const validationErrors: {[K: string]: string | string[]} = reason['validationErrors'];
                for(let [field, message] of Object.entries<any>(validationErrors)) {
                  if (field !== 'machines') {
                    setFieldError(field, new String(message).toString());
                  } else {
                    setMachineErrors(message);
                  }
                }
              } else {
                console.error(reason);
              }
            })
            .finally(() => setSubmitting(false));
        }}
      >
      {({isValid, isSubmitting, setFieldTouched}) => (
        <Form>
          <div className="card-content">
            <div className="field">
              <label className="label">Cluster Name *</label>
              <div className="control">
                <Field required className="input" type="text" name="title" disabled={isSubmitting} data-testid="title" />
              </div>
              <p className="help">
                Name or title of the cluster.
              </p>
              <ErrorMessage name="title" render={(message) => (
                <p className="help is-danger">{message}</p>
              )} />
            </div>

            <div className="field">
              <label className="label">Username *</label>
              <div className="control">
                <Field required className="input" type="text" name="userName" disabled={isSubmitting} data-testid="userName" />
              </div>
              <p className="help">
                Username to connect to machines in the data center.
                All machines used for load generation should authorize this user for login.
              </p>
              <ErrorMessage name="userName" render={(message) => (
                <p className="help is-danger">{message}</p>
              )} />
            </div>

            <div className="field">
              <label className="label">SSH Identity *</label>
              <div className="control">
                <FileUpload
                  name="pemFile"
                  onAccept={(file) => {
                    setPemFile(file);
                    setFieldTouched('pemFile', true);
                  }}
                  disabled={isSubmitting}
                  preventDefault={true}
                  accept=".pem"
                >
                  <div className="file has-name is-right is-fullwidth">
                    <label className="file-label">
                      <span className="file-cta">
                        <span className="file-icon">
                          <i className="fas fa-upload"></i>
                        </span>
                        <span className="file-label">
                          Choose a file…
                        </span>
                      </span>
                      <span className="file-name">
                        {pemFile && pemFile.name}
                      </span>
                    </label>
                  </div>
                </FileUpload>
              </div>
              <p className="help">
                SSH identity (a *.pem file) for all machines that are used for load generation.
              </p>
            </div>

            <div className="field">
              <label className="label">Machines *</label>
              <div className="control">
                <MachineSet
                  disabled={isSubmitting}
                  name="machines"
                  onChange={(machines) => {
                    setMachines(machines);
                    if (machines.length > 0) setFieldTouched('machines', true);
                  }}
                  {...{machineErrors}}
                />
              </div>
              <p className="help">
                These are the machines for load generation. They need to be set up already. At least one
                machine needs to be added.
                Check the <a
                  href="https://github.com/3pillarlabs/hailstorm-sdk/wiki/Physical-Machines-for-Load-Generation"
                  target="_blank"
                >
                  Hailstorm wiki page
                </a> for more information.
              </p>
              <p className="help">
                <span className="icon has-text-info">
                  <i className="fas fa-lightbulb"></i>
                </span> Try pasting a list or space separated host names or IP addresses.
              </p>
            </div>

            <div className="field">
              <label className="label">SSH Port</label>
              <div className="control">
                <Field
                  className="input"
                  type="number"
                  name="sshPort"
                  disabled={isSubmitting}
                  minimum={0}
                  maximum={65535}
                  data-testid="sshPort" />
              </div>
              <p className="help">
                SSH port for all machines that are used for load generation.
              </p>
            </div>
          </div>
          <div className="card-footer">
            <div className="card-footer-item">
              <button
                type="button"
                className="button is-warning"
                role="Remove Cluster"
                onClick={() => dispatch(new RemoveClusterAction())}
              >
                Remove
              </button>
            </div>
            <div className="card-footer-item">
              <button type="submit" className="button is-dark" disabled={isSubmitting || !isValid}>Save</button>
            </div>
          </div>
        </Form>
      )}
      </Formik>
    </div>
  )
}
