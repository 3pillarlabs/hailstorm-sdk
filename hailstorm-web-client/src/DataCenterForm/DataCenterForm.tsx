import React, { useState } from "react";
import {Formik, Form, FormikActions} from "formik";
import { DataCenterCluster, Project, DataCenterClusterInputs } from "../domain";
import { ClusterFormFooter } from "../ClusterConfiguration/ClusterFormFooter";
import styles from '../NewProjectWizard/NewProjectWizard.module.scss';
import { RemoveCluster } from "../ClusterConfiguration/RemoveCluster";
import { useNotifications } from "../app-notifications";
import { ClusterTitle } from "./ClusterTitle";
import { ClusterUser } from "./ClusterUser";
import { ClusterKeyFile } from "./ClusterKeyFile";
import { ClusterMachineSet } from "./ClusterMachineSet";
import { ClusterSSHPort } from "./ClusterSSHPort";

type DataCenterFormValues = DataCenterClusterInputs & {
  pemFile: File | undefined;
};

const DEFAULT_SSH_PORT = 22;

export function DataCenterForm({
  onSubmit,
  pemFile,
  setPemFile,
  machines,
  setMachines,
  activeProject,
  dispatch,
  formMode = "new",
  cluster
}: {
  onSubmit: ({
    userName,
    sshPort,
    title,
  }: {
    title: string;
    userName: string;
    sshPort: number;
  }, actions: {
    resetForm(nextValues?: any | undefined): void;
  }) => Promise<any>;
  pemFile: File | undefined;
  setPemFile: React.Dispatch<React.SetStateAction<File | undefined>>;
  machines: string[];
  setMachines: React.Dispatch<React.SetStateAction<string[]>>;
  activeProject?: Project;
  dispatch?: React.Dispatch<any>;
  formMode?: "new" | "edit" | "readOnly";
  cluster?: DataCenterCluster;
}) {
  const [machineErrors, setMachineErrors] = useState<{[K: string]: string}>();
  const {notifyError} = useNotifications();
  const readOnlyMode = formMode === 'readOnly';
  const initialValues: DataCenterFormValues = cluster ? {
    ...cluster,
    pemFile: undefined
  } : {
    title: "",
    userName: "",
    sshPort: DEFAULT_SSH_PORT,
    pemFile: undefined,
    machines: []
  };

  if (initialValues.sshPort === undefined) {
    initialValues.sshPort = DEFAULT_SSH_PORT;
  }

  const validate = ({
    title,
    userName,
    sshPort
  }: {
    title: string;
    userName: string;
    sshPort?: number;
  }) => {
    const errors: { [k: string]: string; } = {};
    if (title.trim() === "") {
      errors.title = "Title can't be blank";
    }

    if (userName.trim() === "") {
      errors.userName = "Username can't be blank";
    }

    if (sshPort === undefined || sshPort.toString().trim() === "" ||
      (sshPort <= 0 ||
        sshPort > 65535 ||
        !sshPort.toString().match(/^\d+$/))) {
      errors.sshPort = "SSH port must be a number within range of 0-65535";
    }

    if (formMode !== 'edit' && pemFile === undefined) {
      errors.pemFile =
        "An SSH identity (private key) file is needed to connect to machines";
    }

    if (machines.length === 0) {
      errors.machines =
        "At least one machine is needed for load generation";
    }

    return errors;
  };

  const handleSubmit: (
    values: DataCenterFormValues,
    actions: FormikActions<DataCenterFormValues>
  ) => void = (
    {sshPort, title, userName},
    {setFieldError, setSubmitting, resetForm}
  ) => {
    setSubmitting(true);
    onSubmit({ title, userName, sshPort: sshPort || DEFAULT_SSH_PORT }, {resetForm})
      .catch((reason) => {
        if (
          typeof reason === "object" &&
          Object.keys(reason).includes("validationErrors")
        ) {
          const validationErrors: { [K: string]: string | string[] } =
            reason["validationErrors"];
          for (let [field, message] of Object.entries<any>(
            validationErrors
          )) {
            if (field !== "machines") {
              setFieldError(field, new String(message).toString());
            } else {
              setMachineErrors(message);
            }
          }
        } else {
          notifyError(
            `Failed to save ${(title)} cluster configuration`,
            reason
          );
        }
      })
      .finally(() => setSubmitting(false));
  }

  return (
    <Formik
      isInitialValid={formMode !== 'new'}
      {...{initialValues, validate}}
      onSubmit={handleSubmit}
    >
      {({ isValid, isSubmitting, setFieldTouched }) => (
        <Form>
          <div className={`card-content${cluster && cluster.disabled ? ` ${styles.disabledContent}` : ''}`}>
            <ClusterTitle disabled={isSubmitting} readOnlyValue={readOnlyMode && cluster ? cluster.title : undefined} />

            <ClusterUser
              disabled={isSubmitting}
              readOnlyValue={readOnlyMode && cluster ? cluster.userName : undefined}
            />

            <ClusterKeyFile
              onAccept={(file) => {
                setPemFile(file);
                setFieldTouched("pemFile", true);
              }}
              disabled={isSubmitting}
              pathPrefix={activeProject ? activeProject.code : undefined}
              pemFile={pemFile}
              readOnlyValue={readOnlyMode && cluster ? cluster.sshIdentity.name : undefined}
              sshIdentityName={cluster ? cluster.sshIdentity.name : undefined}
            />

            <ClusterMachineSet
              disabled={isSubmitting}
              onChange={(machines) => {
                setMachines(machines);
                if (machines.length > 0) setFieldTouched("machines", true);
              }}
              readOnlyMode={readOnlyMode && cluster !== undefined}
              {...{machines, machineErrors}}
            />

            <ClusterSSHPort
              disabled={isSubmitting}
              readOnlyValue={readOnlyMode && cluster ? cluster.sshPort || DEFAULT_SSH_PORT : undefined}
            />
          </div>
          {formMode === 'new' && dispatch ? (
          <ClusterFormFooter
            {...{ dispatch }}
            disabled={isSubmitting || !isValid}
          />) : (activeProject && cluster && dispatch && (
          <div className="card-footer">
            <RemoveCluster {...{activeProject, cluster, dispatch}} />
            {!cluster.disabled && (
              <div className="card-footer-item">
                <button
                  type="submit"
                  className="button is-primary"
                  role="Update Cluster"
                  disabled={isSubmitting || !isValid}
                >
                  Update
                </button>
              </div>
            )}
          </div>
          ))}
        </Form>
      )}
    </Formik>
  );
}
