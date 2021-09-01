import React, { useState } from 'react';

export function NonLinearSlider({
  initialValue,
  onChange,
  minimum,
  maximum,
  step,
  disabled
}: {
  initialValue?: number;
  onChange: (value: number) => void;
  minimum?: number;
  maximum?: number;
  step?: number;
  disabled?: boolean;
}) {
  const minimumValue = minimum || 0;
  const maximumValue = maximum || 1000;
  const stepValue = step || 10;
  const [maxUsers, setMaxUsers] = useState<number>(initialValue || 0);
  const handleChange = (event: {target: {value: any}}) => {
    let nextValue = event.target.value;
    if (nextValue > maximumValue) {
      nextValue = maximumValue;
    };

    setMaxUsers(nextValue);
    onChange(nextValue);
  };

  const handleBlur = (event: {target: {value: any}}) => {
    let nextValue = event.target.value;
    if (nextValue < minimumValue) {
      nextValue = minimumValue;
    };

    setMaxUsers(nextValue);
  };

  return (
    <div className="field">
      <label className="label">
        Maximum number of users you plan to test for
      </label>
      <div className="control">
        <input
          type="number"
          className="input"
          min={minimumValue || 50}
          max={maximumValue || 5000}
          step={stepValue || 50}
          value={maxUsers}
          onChange={handleChange}
          onBlur={handleBlur}
          disabled={disabled}
          data-testid="MaxPlannedUsers"
        />
      </div>
      <p className="help">
        This is a number between {minimumValue} and {maximumValue} which will automatically select an
        AWS EC2 instance type that minimizes cluster cost.
      </p>
    </div>
  );
}
