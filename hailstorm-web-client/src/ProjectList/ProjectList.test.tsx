import React from 'react';
import { Project, ExecutionCycleStatus } from '../domain';
import { mount } from 'enzyme';
import { MemoryRouter, Route } from 'react-router-dom';
import { ProjectList } from './ProjectList';
import { ProjectService } from "../services/ProjectService";
import { AppStateProviderWithProps } from '../AppStateProvider/AppStateProvider';
import { AppNotificationProviderWithProps } from '../AppNotificationProvider/AppNotificationProvider';
import { AppNotificationContextProps } from '../app-notifications';
import { render } from '@testing-library/react';

describe('<ProjectList />', () => {

  function ComponentWrapper({
    notifiers,
    loadRetryInterval,
    maxLoadRetries,
    dispatch,
    children,
    initialEntries
  }: React.PropsWithChildren<{
    notifiers?: {[K in keyof AppNotificationContextProps]?: AppNotificationContextProps[K]};
    loadRetryInterval?: number;
    maxLoadRetries?: number;
    dispatch?: React.Dispatch<any>;
    initialEntries?: Array<any>;
  }>) {
    const {notifyError, notifyInfo, notifySuccess, notifyWarning} = notifiers || {};

    return (
      <AppStateProviderWithProps
        appState={{activeProject: undefined, runningProjects: []}}
        dispatch={dispatch || jest.fn()}
      >
        <AppNotificationProviderWithProps
          notifyError={notifyError || jest.fn()}
          notifyInfo={notifyInfo || jest.fn()}
          notifySuccess={notifySuccess || jest.fn()}
          notifyWarning={notifyWarning || jest.fn()}
        >
          <MemoryRouter {...{initialEntries}}>
            <ProjectList {...{loadRetryInterval, maxLoadRetries}} />
            {children}
          </MemoryRouter>
        </AppNotificationProviderWithProps>
      </AppStateProviderWithProps>
    );
  }

  beforeEach(() => {
    jest.resetAllMocks();
  });

  it('should show the loader when projects are being fetched', () => {
    jest.spyOn(ProjectService.prototype, "list").mockResolvedValue([]);
    const component = mount(<ComponentWrapper />);
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

    const component = mount(<ComponentWrapper />);
    await dataPromise;
    component.update();

    expect(apiSpy).toBeCalled();
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
      <ComponentWrapper
        initialEntries={['/projects']}
      >
        <Route exact path="/wizard/projects/new" component={NewProjectWizard} />
      </ComponentWrapper>
    );

    await emptyPromise;
    component.update();
    expect(component).toContainExactlyOneMatchingElement("#NewProjectWizard");
  });

  describe('on project list API call error', () => {

    it('should retry the call', async (done) => {
      const listSpy = jest.spyOn(ProjectService.prototype, 'list').mockRejectedValue('Network error');
      render(<ComponentWrapper loadRetryInterval={10} />);
      setTimeout(() => {
        done();
        expect(listSpy.mock.calls.length).toBeGreaterThan(1);
      }, 50);
    });

    it('should notify on eventual failure', (done) => {
      jest.spyOn(ProjectService.prototype, 'list').mockRejectedValue("Network error");
      const notifyError = jest.fn();
      render(<ComponentWrapper notifiers={{notifyError}} loadRetryInterval={10} />);
      setTimeout(() => {
        done();
        expect(notifyError).toHaveBeenCalledTimes(1);
      }, 50);
    });

    it('should be able to eventually succeed', (done) => {
      const listSpy = jest
        .spyOn(ProjectService.prototype, 'list')
        .mockRejectedValueOnce("Network Error")
        .mockRejectedValueOnce("Network Error")
        .mockResolvedValueOnce([]);

      const notifyError = jest.fn();
      const notifyWarning = jest.fn();
      const dispatch = jest.fn();
      render(
        <ComponentWrapper
          notifiers={{notifyWarning, notifyError}}
          loadRetryInterval={10}
          maxLoadRetries={3}
          {...{dispatch}}
        />
      );

      setTimeout(() => {
        done();
        expect(listSpy).toHaveBeenCalledTimes(3);
        expect(notifyWarning).toHaveBeenCalledTimes(2);
        expect(dispatch).toHaveBeenCalled();
        expect(notifyError).not.toHaveBeenCalled();
      }, 50);
    });
  });
});
