import React from "react";

export function IdentityPanel({
  sshIdentityName, setEditable
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
  );
}
