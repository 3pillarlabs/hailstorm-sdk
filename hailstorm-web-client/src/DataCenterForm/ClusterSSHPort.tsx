import React from "react";
import { Field } from "formik";
import { ReadOnlyField } from "../ClusterConfiguration/ReadOnlyField";

export function ClusterSSHPort(props: { disabled: boolean; readOnlyValue?: any; }) {
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
          data-testid="sshPort" />
      </div>
      <p className="help">
        SSH port for all machines that are used for load generation.
      </p>
    </div>
  );
}
