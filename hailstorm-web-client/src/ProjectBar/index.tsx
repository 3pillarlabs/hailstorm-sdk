import React from 'react';
import { Project } from '../domain';
import { ProjectBarItem } from "../ProjectBarItem";

interface ProjectBarProps {
  maxColumns: number;
}

interface ProjectBarState {
  activeProject: Project,
  shownProjects: Project[];
  dropdownProjects: Project[];
}

/**
 * Displays projects with running tests.
 *
 */
export class ProjectBar extends React.Component<ProjectBarProps, ProjectBarState> {

  constructor(props: ProjectBarProps) {
    super(props);

    this.state = {
      activeProject: { code: "hailstorm_ocean", title: "Hailstorm Basic Priming test with Digital Ocean droplets and custom JMeter" },
      shownProjects: [],
      dropdownProjects: []
    };
  }

  render() {
    return (
      <>
        <ProjectBarItem
          key={this.state.activeProject.code}
          code={this.state.activeProject.code}
          title={this.state.activeProject.title}
          clickHandler={this.handleNavigation.bind(this)}
        />

        {this.state.shownProjects.map(project => (
        <ProjectBarItem
          key={project.code}
          code={project.code}
          title={project.title}
          clickHandler={this.handleNavigation.bind(this)}
        />
        ))}
        <div className="navbar-item has-dropdown is-hoverable">
          <a className="navbar-link">More</a>
          <div className="navbar-dropdown">
          {this.state.dropdownProjects.map(project => (
            <ProjectBarItem
              key={project.code}
              code={project.code}
              title={project.title}
              clickHandler={this.handleNavigation.bind(this)}
            />
          ))}
          </div>
        </div>
      </>
    );
  }

  componentDidMount() {
    const allRunning = this.fetchAllRunningProjects();
    this.setState(() => {
      return {
        shownProjects: allRunning.slice(1, this.props.maxColumns),
        dropdownProjects: allRunning.slice(this.props.maxColumns)
      }
    });
  }

  handleNavigation(event: React.SyntheticEvent) {
    const allRunning = this.fetchAllRunningProjects();
    const navCode = event.currentTarget.getAttribute("data-code");
    if (!navCode) throw new Error(`${event.currentTarget.nodeName} has no "data-code" attribute`);

    const sortedRunning: Project[] = [];
    const nextActiveProject = allRunning.find((project) => project.code === navCode);
    if (!nextActiveProject) throw new Error(`No project matches code: ${navCode}`);

    sortedRunning.push(nextActiveProject);
    sortedRunning.push(...allRunning.filter((project) => project.code !== navCode));

    this.setState(() => {
      return {
        activeProject: nextActiveProject,
        shownProjects: sortedRunning.slice(1, this.props.maxColumns),
        dropdownProjects: sortedRunning.slice(this.props.maxColumns)
      }
    });
  }

  private fetchAllRunningProjects(): Project[] {
    return [
      { code: "hailstorm_ocean", title: "Hailstorm Basic Priming test with Digital Ocean droplets and custom JMeter" },
      { code: "acme_endurance", title: "Acme Endurance" },
      { code: "acme_30_burst", title: "Acme 30 Burst" },
      { code: "acme_60_burst", title: "Acme 60 Burst" },
      { code: "acme_90_burst", title: "Acme 90 Burst" },
      { code: "hailstorm_basic", title: "Hailstorm Basic" },
      { code: "cadent_capacity", title: "Cadent Capacity" },
    ];
  }
}
