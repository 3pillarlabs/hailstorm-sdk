import React from 'react';
import { ellipsis } from '../helpers';

interface ProjectBarItemProps {
  isActive?: boolean;
  code: string;
  title: string;
  clickHandler: (event: React.SyntheticEvent) => void
}

export const ProjectBarItem: React.FC<ProjectBarItemProps> = (props) => {
  const className = `navbar-item${props.isActive ? " is-active" : ""}`;
  let [displayTitle, isTruncated] = ellipsis({longText: props.title});
  return (
    <a
      className={className}
      title={isTruncated ? props.title : undefined}
      data-code={props.code}
      onClick={props.clickHandler}
    >
      <h2>{displayTitle}</h2>
    </a>
  );
}
