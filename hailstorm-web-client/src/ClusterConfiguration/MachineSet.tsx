import React, { useState } from 'react';

export function MachineSet({
  disabled,
  machineErrors,
  onChange,
}: {
  name?: string;
  disabled?: boolean;
  onChange: (machines: string[]) => void;
  machineErrors?: {[K: string]: string};
}) {
  const [machines, setMachines] = useState<string[]>(['', '']);

  const handleChange: (
    value: string,
    index: number
  ) => void = (value, index) => {
    let nextMachines: string[] = [...machines.filter((value) => value !== '')];
    if (value !== '') {
      const multiple = value.split(/[\s]/);
      if (multiple.length === 1) {
        nextMachines[index] = value;
      } else {
        nextMachines[index] = multiple[0];
        multiple.slice(1).forEach((value) => nextMachines.push(value));
      }
    } else {
      nextMachines = nextMachines.filter((_, idx) => idx !== index);
    }

    if (nextMachines.length === 0) {
      setMachines(['', '']);
    } else {
      setMachines([...nextMachines, '']);
    }

    onChange(nextMachines);
  };

  return (
   <>
   {machines.map((machine, index) => (
     <div className="field" key={index}>
      <div className="control">
        <input
          required={index === 0 ? true : undefined}
          className="input"
          type="text"
          disabled={disabled}
          value={machine}
          onChange={(event: {target: {value: string}}) => handleChange(event.target.value.trim(), index)}
        />
      </div>
      {machineErrors && (machine in machineErrors) && (
      <p className="help is-danger">{machineErrors[machine]}</p>
      )}
     </div>
   ))}
   </>
  );
}
