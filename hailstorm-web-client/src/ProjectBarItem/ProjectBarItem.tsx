import React from 'react';
import { ellipsis } from '../helpers';
import { NavLink } from 'react-router-dom';
import { Project } from '../domain';

interface ProjectBarItemProps {
  isActive?: boolean;
  project: Project;
  clickHandler: (event: React.SyntheticEvent) => void
}

export const ProjectBarItem: React.FC<ProjectBarItemProps> = (props) => {
  const className = `navbar-item${props.isActive ? " is-active" : ""}`;
  let [displayTitle, isTruncated] = ellipsis({longText: props.project.title});
  return (
    <NavLink
      to={{pathname: `/projects/${props.project.id}`, state: {project: props.project}}}
      className={className}
      title={isTruncated ? props.project.title : undefined}
      data-code={props.project.id}
      onClick={props.clickHandler}
      activeClassName="is-active"
    >
      <h2>{displayTitle}</h2>
    </NavLink>
  );
}
