import React, { useContext } from 'react';
import { Project } from '../domain';
import { ProjectBarItem } from "../ProjectBarItem";
import { RunningProjectsContext } from '../RunningProjectsProvider';

export interface ProjectBarProps {
  maxColumns: number;
}

export const ProjectBar: React.FC<ProjectBarProps> = (props) => {
  const {runningProjects} = useContext(RunningProjectsContext);
  const key:string = runningProjects.reduce((acc, project) => acc += project.id, '');
  return (<ProjectBarHolder {...props} {...{runningProjects, key}} />);
}

interface ProjectBarHolderProps extends ProjectBarProps {
  runningProjects: Project[];
}

interface ProjectBarState {
  runningProjects: Project[];
  activeProject: Project | undefined,
  shownProjects: Project[];
  dropdownProjects: Project[];
}

class ProjectBarHolder extends React.Component<ProjectBarHolderProps, ProjectBarState> {

  constructor(props: ProjectBarHolderProps) {
    super(props);
    this.state = {
      runningProjects: this.props.runningProjects,
      activeProject: this.props.runningProjects.length > 0 ? this.props.runningProjects[0] : undefined,
      shownProjects: this.props.runningProjects.slice(1, this.props.maxColumns),
      dropdownProjects: this.props.runningProjects.slice(this.props.maxColumns)
    }
  }

  render() {
    console.debug(this.props);
    return (
      <>
      {this.state.activeProject &&
      <ProjectBarItem
        key={this.state.activeProject.code}
        code={this.state.activeProject.id.toString()}
        title={this.state.activeProject.title}
        clickHandler={this.handleNavigation.bind(this)}
      />}

      {this.state.shownProjects.map(project => (
      <ProjectBarItem
        key={project.code}
        code={project.id.toString()}
        title={project.title}
        clickHandler={this.handleNavigation.bind(this)}
      />
      ))}

      {this.state.dropdownProjects.length > 0 &&
      <div className="navbar-item has-dropdown is-hoverable">
        <a className="navbar-link">More</a>
        <div className="navbar-dropdown">
        {this.state.dropdownProjects.map(project => (
          <ProjectBarItem
            key={project.code}
            code={project.id.toString()}
            title={project.title}
            clickHandler={this.handleNavigation.bind(this)}
          />
        ))}
        </div>
      </div>}
      </>
    );
  }

  handleNavigation(event: React.SyntheticEvent) {
    const navCode = event.currentTarget.getAttribute("data-code");
    if (!navCode) throw new Error(`${event.currentTarget.nodeName} has no "data-code" attribute`);

    const sortedRunning: Project[] = [];
    const nextActiveProject = this.state.runningProjects.find((project) => project.id.toString() === navCode);
    if (!nextActiveProject) throw new Error(`No project matches code: ${navCode}`);

    sortedRunning.push(nextActiveProject);
    sortedRunning.push(...this.state.runningProjects.filter((project) => project.id.toString() !== navCode));

    this.setState((prevState) => {
      return {
        ...prevState,
        activeProject: nextActiveProject,
        shownProjects: sortedRunning.slice(1, this.props.maxColumns),
        dropdownProjects: sortedRunning.slice(this.props.maxColumns)
      }
    });
  }
}
