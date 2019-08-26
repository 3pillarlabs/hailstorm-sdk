import React from 'react';
import { Project, ExecutionCycleStatus } from '../domain';
import { mount, ReactWrapper } from 'enzyme';
import { HashRouter } from 'react-router-dom';
import { act } from '@testing-library/react';
import { ProjectList } from './ProjectList';
import { AppStateContext } from '../appStateContext';
import { ProjectService } from '../api';

describe('<ProjectList />', () => {
  it('should show the loader when projects are being fetched', () => {
    jest.spyOn(ProjectService.prototype, "list").mockResolvedValue([]);
    let component: ReactWrapper;
    act(() => {
      component = mount(
        <AppStateContext.Provider value={{appState: {activeProject: undefined, runningProjects: []}, dispatch: jest.fn()}}>
          <ProjectList />
        </AppStateContext.Provider>
      );
    });

    expect(component!).toContainExactlyOneMatchingElement('Loader');
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

    const apiSpy = jest.spyOn(ProjectService.prototype, 'list').mockResolvedValue(eventualData);

    let component: ReactWrapper;
    act(() => {
      component = mount(
        <AppStateContext.Provider value={{appState: {activeProject: undefined, runningProjects: []}, dispatch: jest.fn()}}>
          <HashRouter>
            <ProjectList />
          </HashRouter>
        </AppStateContext.Provider>
      );
    });

    expect(apiSpy).toBeCalled();
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
