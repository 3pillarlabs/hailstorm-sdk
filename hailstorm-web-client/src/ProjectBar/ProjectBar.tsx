import React, { useState, useEffect } from 'react';
import { Project } from '../domain';
import { ProjectBarItem } from './ProjectBarItem';

export interface ProjectBarProps {
  runningProjects: Project[];
  maxItems?: number;
}

export const ProjectBar: React.FC<ProjectBarProps> = ({maxItems, runningProjects} = {maxItems: 10, runningProjects: []}) => {
  const [projectItems, setProjectItems] = useState<Project[]>([]);
  const projectCompareFn = (a: Project, b: Project) =>
    a.currenExecutionCycle && b.currenExecutionCycle
      ? b.currenExecutionCycle.startedAt.getTime() - a.currenExecutionCycle.startedAt.getTime()
      : b.id - a.id

  useEffect(() => {
    console.debug('ProjectBar#useEffect(runningProjects)');
    const sortedByStartedAt = [...runningProjects].sort(projectCompareFn);
    setProjectItems(sortedByStartedAt);
  }, [runningProjects]);

  const activeProject: Project | null = projectItems.length > 0 ? projectItems[0] : null;
  const otherRunningProjects: Project[] = projectItems.slice(1, maxItems);
  const dropdownProjects: Project[] = projectItems.slice(maxItems);

  return (
    <>
    {activeProject &&
    <ProjectBarItem
      key={projectItems[0].code}
      project={projectItems[0]}
    />}

    {otherRunningProjects.map(project => (
    <ProjectBarItem
      key={project.code}
      project={project}
    />
    ))}

    {dropdownProjects.length > 0 &&
    <div className="navbar-item has-dropdown is-hoverable">
      <a className="navbar-link">More</a>
      <div className="navbar-dropdown">
      {dropdownProjects.map(project => (
        <ProjectBarItem
          key={project.code}
          project={project}
        />
      ))}
      </div>
    </div>}
    </>
  );
}
