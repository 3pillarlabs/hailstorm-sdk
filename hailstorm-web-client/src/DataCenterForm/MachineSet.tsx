import React, { useEffect, useState } from 'react';

export function MachineSet({
  disabled,
  machineErrors,
  onChange,
  machines
}: {
  onChange: (machines: string[]) => void;
  machines: string[];
  name?: string;
  disabled?: boolean;
  machineErrors?: {[K: string]: string};
}) {
  const [inputFields, setInputFields] = useState<string[]>(['', '']);

  const handleChange: (
    value: string,
    index: number
  ) => void = (value, index) => {
    let nextMachines: string[] = [...inputFields.filter((value) => value !== '')];
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
      setInputFields(['', '']);
    } else {
      setInputFields([...nextMachines, '']);
    }

    onChange(nextMachines);
  };

  useEffect(() => {
    console.debug("MachineSet#useEffect(machines)");
    if (machines.length > 0) {
      setInputFields([...machines, '']);
    }
  }, [machines]);

  return (
   <>
   {inputFields.map((machine, index) => (
     <div className="field" key={index}>
      <div className="control">
        <input
          required={index === 0 ? true : undefined}
          className="input"
          type="text"
          disabled={disabled}
          value={machine}
          data-testid="dc-machine"
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
