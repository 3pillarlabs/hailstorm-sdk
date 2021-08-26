import React from "react";
import { MachineSet } from "../ClusterConfiguration/MachineSet";
import { ReadOnlyField } from "../ClusterConfiguration/ReadOnlyField";

export function ClusterMachineSet({
  disabled, onChange, machineErrors, machines, readOnlyMode
}: {
  disabled: boolean;
  onChange: (machines: string[]) => void;
  machineErrors: { [p: string]: string; } | undefined;
  machines: string[];
  readOnlyMode?: boolean;
}) {
  if (readOnlyMode) {
    return (
      <div className="field">
        <label className="label">Machines</label>
        <div className="control">
          {machines.map((value) => (<ReadOnlyField {...{ value }} />))}
        </div>
      </div>
    );
  }

  return (
    <div className="field">
      <label className="label">Machines *</label>
      <div className="control" data-testid="MachineSet">
        <MachineSet
          name="machines"
          onChange={onChange}
          {...{ machineErrors, machines, disabled }} />
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
