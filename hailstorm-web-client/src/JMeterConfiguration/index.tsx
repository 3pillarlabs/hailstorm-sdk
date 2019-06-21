import React from 'react';

export interface JMeterConfigurationProps {
  transition: () => void;
}

export const JMeterConfiguration: React.FC<JMeterConfigurationProps> = (props) => {
  return (
    <>
    <h3 className="title is-3">Setup JMeter</h3>
    <button className="button is-primary" onClick={props.transition}>Next</button>
    </>
  );
}
