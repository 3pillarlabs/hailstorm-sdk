import React from 'react';
import { Project, ExecutionCycleStatus } from '../domain';
import { mount } from 'enzyme';
import { MemoryRouter, Route } from 'react-router-dom';
import { ProjectList } from './ProjectList';
import { AppStateContext } from '../appStateContext';
import { ProjectService } from "../services/ProjectService";

describe('<ProjectList />', () => {
  it('should show the loader when projects are being fetched', () => {
    jest.spyOn(ProjectService.prototype, "list").mockResolvedValue([]);
    const component = mount(
      <AppStateContext.Provider value={{appState: {activeProject: undefined, runningProjects: []}, dispatch: jest.fn()}}>
        <MemoryRouter>
          <ProjectList />
        </MemoryRouter>
      </AppStateContext.Provider>
    );

    expect(component!).toContainExactlyOneMatchingElement('Loader');
  });

  it('should show the projects when available', async () => {
    const dataPromise = Promise.resolve<Project[]>([
      {
        id: 1,
        code: 'a',
        title: 'A',
        autoStop: true,
        running: true,
        lastExecutionCycle: {
          id: 10, projectId: 1, startedAt: new Date(), threadsCount: 50
        },
        currentExecutionCycle: {
          id: 1000, projectId: 1, startedAt: new Date(), threadsCount: 100
        }
      },
      {
        id: 2, code: 'b', title: 'B', autoStop: true, running: false, lastExecutionCycle: {
          id: 10, projectId: 2, startedAt: new Date(), stoppedAt: new Date(), status: ExecutionCycleStatus.STOPPED
        }
      },
      {
        id: 3, code: 'c', title: 'C', autoStop: true, running: false, lastExecutionCycle: {
          id: 20, projectId: 3, startedAt: new Date(), stoppedAt: new Date(), status: ExecutionCycleStatus.ABORTED
        }
      },
      {
        id: 4, code: 'd', title: 'D', autoStop: true, running: false
      },
      {
        id: 5, code: 'e', title: 'E', autoStop: false, running: false, lastExecutionCycle: {
          id: 30, projectId: 5, startedAt: new Date(), status: ExecutionCycleStatus.FAILED
        }
      },
      {
        id: 6, code: 'f', title: 'F', running: false, incomplete: true
      }
    ]);

    const apiSpy = jest.spyOn(ProjectService.prototype, 'list').mockReturnValueOnce(dataPromise);

    const component = mount(
      <AppStateContext.Provider value={{appState: {activeProject: undefined, runningProjects: []}, dispatch: jest.fn()}}>
        <MemoryRouter>
          <ProjectList />
        </MemoryRouter>
      </AppStateContext.Provider>
    );

    expect(apiSpy).toBeCalled();
    await dataPromise;
    component.update();
    console.debug(component.html());
    expect(component.find('div.running')).toContainMatchingElements(1, '.is-warning');
    expect(component.find('div.justCompleted')).toContainMatchingElements(1, '.is-success');
    expect(component.find('div.justCompleted')).toContainMatchingElements(1, '.is-warning');
    expect(component.find('div.others')).toContainMatchingElements(2, '.is-light');
  });

  it('should redirect to new project wizard if there are no projects', async () => {
    const emptyPromise = Promise.resolve<Project[]>([]);
    jest.spyOn(ProjectService.prototype, 'list').mockReturnValueOnce(emptyPromise);
    const NewProjectWizard = () => (
      <div id="NewProjectWizard"></div>
    );

    const component = mount(
      <AppStateContext.Provider value={{appState: {activeProject: undefined, runningProjects: []}, dispatch: jest.fn()}}>
        <MemoryRouter initialEntries={['/projects']}>
          <ProjectList />
          <Route exact path="/wizard/projects/new" component={NewProjectWizard} />
        </MemoryRouter>
      </AppStateContext.Provider>
    );

    await emptyPromise;
    component.update();
    expect(component).toContainExactlyOneMatchingElement("#NewProjectWizard");
  });
});
