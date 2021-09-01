import React from "react";
import { Field, ErrorMessage } from "formik";
import { ReadOnlyField } from "../ClusterConfiguration/ReadOnlyField";

export function ClusterUser({
  disabled, readOnlyValue
}: {
  disabled?: boolean;
  readOnlyValue?: any;
}) {
  if (readOnlyValue !== undefined) {
    return (
      <ReadOnlyField label="Username" value={readOnlyValue} />
    );
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
          data-testid="userName" />
      </div>
      <p className="help">
        Username to connect to machines in the data center. All machines used
        for load generation should authorize this user for login.
      </p>
      <ErrorMessage
        name="userName"
        render={(message) => <p className="help is-danger">{message}</p>} />
    </div>
  );
}
