import React from 'react';

export interface ClusterConfigurationProps {
  transition: () => void;
}

export const ClusterConfiguration: React.FC<ClusterConfigurationProps> = (props) => {
  return (
    <>
    <h3 className="title is-3">Setup Clusters</h3>
    <button className="button is-primary" onClick={props.transition}>Next</button>
    </>
  );
}
