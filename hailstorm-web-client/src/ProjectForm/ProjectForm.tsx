import React from 'react';

export interface ProjectFormProps {
  transition: (id: string | number) => void;
}

export const ProjectForm: React.FC<ProjectFormProps> = (props) => {
  return (
    <>
      <h3 className="title is-3">Setup a new Project</h3>
      <button className="button is-primary" onClick={() => props.transition(7)}>Next</button>
    </>
  );
}
