import React from "react";
import { FileUpload } from "../FileUpload/FileUpload";

export function FileUploadField({
  onAccept, disabled, pathPrefix, pemFile, setEditable
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
