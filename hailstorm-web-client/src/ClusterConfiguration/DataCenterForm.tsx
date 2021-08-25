import React, { useState } from "react";
import {Formik, Form, Field, ErrorMessage, FormikActions} from "formik";
import { FileUpload } from "../FileUpload";
import { MachineSet } from "./MachineSet";
import { DataCenterCluster, Project, DataCenterClusterInputs } from "../domain";
import { ClusterFormFooter } from "./ClusterFormFooter";
import { ReadOnlyField } from "./ReadOnlyField";
import styles from '../NewProjectWizard/NewProjectWizard.module.scss';
import { RemoveCluster } from "./RemoveCluster";
import { useNotifications } from "../app-notifications";

function ClusterTitle({
  disabled,
  readOnlyValue
}: {
  disabled?: boolean,
  readOnlyValue?: any
}) {
  if (readOnlyValue !== undefined) {
    return (
      <ReadOnlyField label="Cluster Name" value={readOnlyValue} />
    )
  }

  return (
    <div className="field">
      <label className="label">Cluster Name *</label>
      <div className="control">
        <Field
          required
          className="input"
          type="text"
          name="title"
          disabled={disabled}
          data-testid="title"
        />
      </div>
      <p className="help">Name or title of the cluster.</p>
      <ErrorMessage
        name="title"
        render={(message) => <p className="help is-danger">{message}</p>}
      />
    </div>
  );
}

function ClusterUser({
  disabled,
  readOnlyValue
}: {
  disabled?: boolean;
  readOnlyValue?: any;
}) {
  if (readOnlyValue !== undefined) {
    return (
      <ReadOnlyField label="Username" value={readOnlyValue} />
    )
  }

  return (
    <div className="field">
      <label className="label">Username *</label>
      <div className="control">
        <Field
          required
          className="input"
          type="text"
          name="userName"
          disabled={disabled}
          data-testid="userName"
        />
      </div>
      <p className="help">
        Username to connect to machines in the data center. All machines used
        for load generation should authorize this user for login.
      </p>
      <ErrorMessage
        name="userName"
        render={(message) => <p className="help is-danger">{message}</p>}
      />
    </div>
  );
}

function FileUploadField({
  onAccept,
  disabled,
  pathPrefix,
  pemFile,
  setEditable
}: {
  onAccept: (file: File) => void;
  disabled: boolean;
  pathPrefix: string | undefined;
  pemFile: File | undefined;
  setEditable?: React.Dispatch<React.SetStateAction<boolean>>;
}) {
  return (
    <div className="field">
      <label className="label">SSH Identity *</label>
      <div className="control">
        <FileUpload
          name="pemFile"
          onAccept={onAccept}
          disabled={disabled}
          preventDefault={true}
          accept=".pem"
          pathPrefix={pathPrefix}
        >
          <div className="file has-name is-right is-fullwidth">
            <label className="file-label">
              <span className="file-cta">
                <span className="file-icon">
                  <i className="fas fa-upload"></i>
                </span>
                <span className="file-label">Choose a file…</span>
              </span>
              <span className="file-name">
                {pemFile && pemFile.name}
              </span>
            </label>
          </div>
        </FileUpload>
      </div>
      <p className="help">
        SSH identity (a *.pem file) for all machines that are used for load
        generation.
      </p>
      {setEditable && (
        <div className="buttons is-centered">
          <button
            data-testid="cancel-edit-ssh-identity"
            type="button"
            onClick={() => setEditable(false)}
            className="button is-white"
          >
            Cancel
          </button>
        </div>
      )}
    </div>
  );
}

function IdentityPanel({
  sshIdentityName,
  setEditable
}: {
  sshIdentityName: string;
  setEditable: React.Dispatch<React.SetStateAction<boolean>>;
}) {
  return (
    <div className="field">
      <label className="label">SSH Identity</label>
      <div className="control">
        <div className="field is-horizontal">
          <div className="control">
            <input className="input is-static" value={sshIdentityName} readOnly={true} />
          </div>
          <div className="control">
            <button
              role="Edit SSH Identity"
              type="button"
              onClick={() => setEditable(true)}
              className="button"
            >
              Change
            </button>
          </div>
        </div>
      </div>
      <p className="help">
        SSH identity (a *.pem file) for all machines that are used for load
        generation.
      </p>
    </div>
  )
}

function ClusterKeyFile({
  onAccept,
  disabled,
  pathPrefix,
  pemFile,
  readOnlyValue,
  sshIdentityName
}: {
  onAccept: (file: File) => void;
  disabled: boolean;
  pathPrefix: string | undefined;
  pemFile: File | undefined;
  readOnlyValue?: any;
  sshIdentityName?: string;
}) {
  const [editable, setEditable] = useState(false);

  if (readOnlyValue !== undefined) {
    return (
      <ReadOnlyField label="SSH Identity" value={readOnlyValue} />
    );
  }

  if (sshIdentityName === undefined || editable) {
    return (
      <FileUploadField {...{
          onAccept,
          disabled,
          pathPrefix,
          pemFile
        }}
        setEditable={editable ? setEditable : undefined}
      />
    )
  }

  return (
    <IdentityPanel {...{
      sshIdentityName,
      setEditable
    }} />
  );
}

function ClusterMachineSet({
  disabled,
  onChange,
  machineErrors,
  machines,
  readOnlyMode
}: {
  disabled: boolean;
  onChange: (machines: string[]) => void;
  machineErrors: { [p: string]: string } | undefined;
  machines: string[];
  readOnlyMode?: boolean;
}) {
  if (readOnlyMode) {
    return (
      <div className="field">
        <label className="label">Machines</label>
        <div className="control">
          {machines.map((value) => (<ReadOnlyField {...{value}} />))}
        </div>
      </div>
    )
  }

  return (
    <div className="field">
      <label className="label">Machines *</label>
      <div className="control" data-testid="MachineSet">
        <MachineSet
          name="machines"
          onChange={onChange}
          {...{ machineErrors, machines, disabled }}
        />
      </div>
      <p className="help">
        These are the machines for load generation. They need to be set up
        already. At least one machine needs to be added. Check the{" "}
        <a
          href="https://github.com/3pillarlabs/hailstorm-sdk/wiki/Physical-Machines-for-Load-Generation"
          target="_blank"
        >
          Hailstorm wiki page
        </a>{" "}
        for more information.
      </p>
      <p className="help">
        <span className="icon has-text-info">
          <i className="fas fa-lightbulb"></i>
        </span>{" "}
        Try pasting a list or space separated host names or IP addresses.
      </p>
    </div>
  );
}

function ClusterSSHPort(props: { disabled: boolean, readOnlyValue?: any }) {
  if (props.readOnlyValue !== undefined) {
    return (
      <ReadOnlyField label="SSH Port" value={props.readOnlyValue} />
    );
  }

  return (
    <div className="field">
      <label className="label">SSH Port</label>
      <div className="control">
        <Field
          className="input"
          type="number"
          name="sshPort"
          disabled={props.disabled}
          minimum={0}
          maximum={65535}
          data-testid="sshPort"
        />
      </div>
      <p className="help">
        SSH port for all machines that are used for load generation.
      </p>
    </div>
  );
}

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
