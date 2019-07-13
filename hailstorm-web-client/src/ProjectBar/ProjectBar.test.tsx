import React, { useState } from 'react';
import ReactDOM from 'react-dom';
import { ProjectBar } from './ProjectBar';
import { shallow, mount, render } from 'enzyme';
import { RunningProjectsCtxProps, RunningProjectsContext } from '../RunningProjectsProvider';
import { ProjectBarItem } from '../ProjectBarItem';
import { Project, ExecutionCycle } from '../domain';
import { HashRouter } from 'react-router-dom';

describe(ProjectBar.name, () => {
  it('renders without crashing', () => {
    shallow(<ProjectBar />);
  });

  describe('with no running projects', () => {
    it ('displays no items', () => {
      const context: RunningProjectsCtxProps = {
        runningProjects: [],
        reloadRunningProjects: () => new Promise((resolve, _) => resolve([]))
      };
      const projectBar = mount(
        <RunningProjectsContext.Provider value={context}>
          <ProjectBar maxItems={2} />
        </RunningProjectsContext.Provider>
      );
      expect(projectBar.exists(ProjectBarItem)).toBeFalsy();
    });
  });

  describe('with running projects', () => {
    it('displays project items', () => {
      const runningProject: Project = {id: 1, title: 'test', code: 'test', autoStop: false, running: true};
      const context: RunningProjectsCtxProps = {
        runningProjects: [runningProject, {...runningProject, id: 2, code: 'test2', title: 'test2'}],
        reloadRunningProjects: () => new Promise((resolve, _) => resolve([]))
      };
      const projectBar = mount(
        <RunningProjectsContext.Provider value={context}>
          <HashRouter>
            <ProjectBar maxItems={2} />
          </HashRouter>
        </RunningProjectsContext.Provider>
      );
      expect(projectBar).toContainMatchingElements(context.runningProjects.length, ProjectBarItem.name);
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
            <RunningProjectsContext.Provider value={{
              runningProjects,
              reloadRunningProjects: () => new Promise((_, reject) => reject(new Error('unexpected')))
              }}
            >
              <HashRouter>
                <ProjectBar maxItems={2} />
              </HashRouter>
            </RunningProjectsContext.Provider>
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
      const context: RunningProjectsCtxProps = {
        runningProjects: [runningProject, {
          ...runningProject,
          id: 2,
          code: 'test2',
          title: 'test2',
          currenExecutionCycle: executionCycle(2, 15)
        }],
        reloadRunningProjects: () => new Promise((_, reject) => reject(new Error('unexpected')))
      };

      console.debug(context.runningProjects);
      const projectBar = mount(
        <RunningProjectsContext.Provider value={context}>
          <HashRouter>
            <ProjectBar maxItems={2} />
          </HashRouter>
        </RunningProjectsContext.Provider>
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
      const context: RunningProjectsCtxProps = {
        runningProjects,
        reloadRunningProjects: () => new Promise((_, reject) => reject(new Error('unexpected')))
      };

      const projectBar = mount(
        <RunningProjectsContext.Provider value={context}>
          <HashRouter>
            <ProjectBar maxItems={2} />
          </HashRouter>
        </RunningProjectsContext.Provider>
      );

      expect(projectBar.find('.navbar-link')).toHaveText('More');
    });
  });
});
