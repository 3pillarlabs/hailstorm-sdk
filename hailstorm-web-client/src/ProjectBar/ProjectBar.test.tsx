import React from 'react';
import { ProjectBar } from './ProjectBar';
import { shallow, mount } from 'enzyme';
import { ProjectBarItem } from './ProjectBarItem';
import { Project, ExecutionCycle } from '../domain';
import { HashRouter } from 'react-router-dom';

describe('<ProjectBar />', () => {
  it('renders without crashing', () => {
    shallow(<ProjectBar runningProjects={[]} />);
  });

  describe('with no running projects', () => {
    it ('displays no items', () => {
      const projectBar = mount(
        <ProjectBar maxItems={2} runningProjects={[]} />
      );
      expect(projectBar.exists(ProjectBarItem)).toBeFalsy();
    });
  });

  describe('with running projects', () => {
    it('displays project items', () => {
      const runningProject: Project = {id: 1, title: 'test', code: 'test', autoStop: false, running: true};
      const runningProjects = [runningProject, {...runningProject, id: 2, code: 'test2', title: 'test2'}];
      const projectBar = mount(
        <HashRouter>
          <ProjectBar maxItems={2} {...{runningProjects}} />
        </HashRouter>
      );
      expect(projectBar).toContainMatchingElements(runningProjects.length, ProjectBarItem.name);
    });

    it('displays changes in running projects', () => {
      type WrapperStateType = {
        runningProjects: Project[]
      };

      class StatefulWrapper extends React.Component<any, WrapperStateType> {
        constructor(props: any) {
          super(props);
          this.state = { runningProjects: [] };
        }

        render() {
          const { runningProjects } = this.state;
          return (
            <HashRouter>
              <ProjectBar maxItems={2} runningProjects={runningProjects} />
            </HashRouter>
          );
        }
      }

      const wrapper = mount(<StatefulWrapper />);
      expect(wrapper.find(ProjectBarItem)).toHaveLength(0);
      wrapper.setState({ runningProjects: [{id: 1, title: 'test', code: 'test', autoStop: false, running: true} as Project] });
      wrapper.setProps({});
      expect(wrapper.find(ProjectBarItem)).toHaveLength(1);
      wrapper.setState({ runningProjects: [] });
      wrapper.setProps({});
      expect(wrapper.find(ProjectBarItem)).toHaveLength(0);
    });

    it('displays the projects in descending order of tests started', () => {
      const executionCycle: (projectId: number, minutesAgo: number) => ExecutionCycle = (projectId, minutesAgo) => ({
        projectId,
        id: (projectId + 100),
        startedAt: new Date(new Date().getTime() - (minutesAgo * 60 * 1000))
      });

      const runningProject: Project = {id: 1, title: 'test', code: 'test', autoStop: false, running: true};
      runningProject.currenExecutionCycle = executionCycle(runningProject.id, 30);

      const projectBar = mount(
        <HashRouter>
          <ProjectBar
            maxItems={2}
            runningProjects={[
              runningProject,
              {
                ...runningProject,
                id: 2,
                code: 'test2',
                title: 'test2',
                currenExecutionCycle: executionCycle(2, 15)
              }
            ]} />
        </HashRouter>
      );

      expect(projectBar.find(ProjectBarItem).at(0).key()).toBe('test2');
      expect(projectBar.find(ProjectBarItem).at(1).key()).toBe('test');
    });

    it('displays more projects dropdown', () => {
      const runningProjects: Project[] = [1, 2, 3].map<Project>(id => ({
        id,
        title: `title${id}`,
        code: `code${id}`,
        running: true,
        autoStop: false
      }));

      const projectBar = mount(
        <HashRouter>
          <ProjectBar maxItems={2} {...{runningProjects}} />
        </HashRouter>
      );

      expect(projectBar.find('.navbar-link')).toHaveText('More');
    });
  });
});
