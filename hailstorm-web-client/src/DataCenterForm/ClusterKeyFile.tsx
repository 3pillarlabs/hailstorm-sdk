import React, { useState } from "react";
import { ReadOnlyField } from "../ClusterConfiguration/ReadOnlyField";
import { FileUploadField } from "./FileUploadField";
import { IdentityPanel } from "./IdentityPanel";

export function ClusterKeyFile({
  onAccept, disabled, pathPrefix, pemFile, readOnlyValue, sshIdentityName
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
        setEditable={editable ? setEditable : undefined} />
    );
  }

  return (
    <IdentityPanel {...{
      sshIdentityName,
      setEditable
    }} />
  );
}
