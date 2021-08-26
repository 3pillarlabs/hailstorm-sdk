import React from "react";
import { Field, ErrorMessage } from "formik";
import { ReadOnlyField } from "../ClusterConfiguration/ReadOnlyField";

export function ClusterTitle({
  disabled, readOnlyValue
}: {
  disabled?: boolean;
  readOnlyValue?: any;
}) {
  if (readOnlyValue !== undefined) {
    return (
      <ReadOnlyField label="Cluster Name" value={readOnlyValue} />
    );
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
          data-testid="title" />
      </div>
      <p className="help">Name or title of the cluster.</p>
      <ErrorMessage
        name="title"
        render={(message) => <p className="help is-danger">{message}</p>} />
    </div>
  );
}
