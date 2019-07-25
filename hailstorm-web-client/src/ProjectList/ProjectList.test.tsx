import React from 'react';
import { Project, ExecutionCycleStatus } from '../domain';
import { mount } from 'enzyme';
import { RunningProjectsContext } from '../RunningProjectsProvider/RunningProjectsProvider';
import { HashRouter } from 'react-router-dom';
import { act } from '@testing-library/react';
import { ProjectList } from './ProjectList';

describe('<ProjectList />', () => {
  it('should show the loader when projects are being fetched', (done) => {
    const runningProjects: Project[] = [];
    const reloadRunningProjects = () => new Promise<Project[]>((resolve, _) => resolve([]));
    act(() => {
      done();
      const component = mount(
        <RunningProjectsContext.Provider value={{runningProjects, reloadRunningProjects}}>
          <ProjectList />
        </RunningProjectsContext.Provider>
      );
      expect(component).toContainExactlyOneMatchingElement('Loader');
    });
  });

  it('should show the projects when available', (done) => {
    const eventualData: Project[] = [
      { id: 1, code: 'a', title: 'A', autoStop: true, running: true, recentExecutionCycle: {
          id: 10, projectId: 1, startedAt: new Date(), stoppedAt: new Date(), status: ExecutionCycleStatus.STOPPED
        }
      },
      {
        id: 2, code: 'b', title: 'B', autoStop: true, running: false, recentExecutionCycle: {
          id: 1, projectId: 2, startedAt: new Date(), stoppedAt: new Date(), status: ExecutionCycleStatus.STOPPED
        }
      },
      {
        id: 3, code: 'c', title: 'C', autoStop: true, running: false, recentExecutionCycle: {
          id: 2, projectId: 3, startedAt: new Date(), stoppedAt: new Date(), status: ExecutionCycleStatus.ABORTED
        }
      },
      {
        id: 4, code: 'd', title: 'D', autoStop: true, running: false
      },
    ];
    const runningProjects: Project[] = [];
    const reloadRunningProjects = () => {
      return new Promise<Project[]>((resolve, _) => {
        runningProjects.pop();
        runningProjects.push(...eventualData.filter((project) => project.running));
        resolve(eventualData);
      });
    };

    act(() => {
      const component = mount(
        <RunningProjectsContext.Provider value={{runningProjects, reloadRunningProjects}}>
          <HashRouter>
            <ProjectList />
          </HashRouter>
        </RunningProjectsContext.Provider>
      );

      setTimeout(() => {
        done();
        component.update();
        expect(component.find('div.nowRunning')).toContainMatchingElements(1, 'article.is-warning');
        expect(component.find('div.justCompleted')).toContainMatchingElements(1, 'article.is-success');
        expect(component.find('div.justCompleted')).toContainMatchingElements(1, 'article.is-warning');
        expect(component.find('div.allProjects')).toContainMatchingElements(2, 'article.is-warning');
        expect(component.find('div.allProjects')).toContainMatchingElements(1, 'article.is-success');
      }, 0);
    });
  });
});
