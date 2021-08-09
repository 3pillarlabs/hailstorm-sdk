import React from 'react';

export function ReadOnlyField({ label, value }: {
  label?: string;
  value: any;
}) {
  return (
    <div className="field" key={label ? undefined : value}>
      {label && (<label className="label">{label}</label>)}
      <div className="control">
        <input readOnly type="text" className="input is-static has-background-light has-text-dark is-size-5" value={value || ''} />
      </div>
    </div>
  );
}
