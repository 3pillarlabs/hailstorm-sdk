import React from 'react';
import { mount, ReactWrapper, shallow } from 'enzyme';
import { ProjectWorkspaceHeader } from './ProjectWorkspaceHeader';
import { act, render, fireEvent, wait } from '@testing-library/react';
import { ProjectService } from "../services/ProjectService";
import { InterimProjectState } from '../domain';
import { AppStateContext } from '../appStateContext';
import { UpdateProjectAction } from '../ProjectWorkspace/actions';
import { AppStateProvider, AppStateProviderWithProps } from '../AppStateProvider/AppStateProvider';
import { AppNotificationProviderWithProps } from '../AppNotificationProvider/AppNotificationProvider';
import { AppNotificationContextProps } from '../app-notifications';

describe('<ProjectWorkspaceHeader />', () => {
  const project = { id: 1, code: 'a', title: 'Project Title', autoStop: true, running: false };
  let component: ReactWrapper | undefined = undefined;
  const dispatch = jest.fn();

  beforeEach(() => {
    act(() => {
      component = mount(
        <AppStateContext.Provider value={{appState: {runningProjects: [], activeProject: project}, dispatch}}>
          <ProjectWorkspaceHeader />
        </AppStateContext.Provider>
      );
    });
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  it('should show project title by default', (done) => {
    setTimeout(() => {
      done();
      expect(component!.find('h2')).toHaveText(project.title);
    }, 0);
  });

  describe('when inline editing', () => {
    beforeEach(() => {
      component!.find('i[title="Edit"]').simulate('click');
    });

    it('should show text field on edit', () => {
      expect(component).toContainExactlyOneMatchingElement('input[type="text"]');
    });

    it('should show title on cancel', () => {
      component!.find('a').simulate('click');
      expect(component!.find('h2')).toHaveText(project.title);
    });

    it('should update title on submit', async () => {
      const updateFnSpy = jest.spyOn(ProjectService.prototype, 'update').mockImplementation(jest.fn().mockResolvedValue(null));
      const notifiers: AppNotificationContextProps = createNotifers();

      const {findByText, findByTitle, findByDisplayValue} = render(
        <AppStateProviderWithProps appState={{runningProjects: [], activeProject: project}} {...{dispatch}}>
          <AppNotificationProviderWithProps {...{...notifiers}}>
            <ProjectWorkspaceHeader />
          </AppNotificationProviderWithProps>
        </AppStateProviderWithProps>
      );

      const editLink = await findByTitle('Edit');
      fireEvent.click(editLink);

      const updatedProjectTitle = `Updated ${project.title}`;
      const textBox = await findByDisplayValue(project.title);
      fireEvent.change(textBox, {target: {value: updatedProjectTitle}});

      const button = await findByText('Update');
      fireEvent.click(button);

      await wait(() => {
        expect(updateFnSpy).toHaveBeenCalledWith(project.id, {title: updatedProjectTitle});
        expect(dispatch).toBeCalled();
        expect(dispatch.mock.calls[0][0]).toBeInstanceOf(UpdateProjectAction);
      });
    });

    it('should not update if title is blank', async () => {
      const {findByText, findByTitle, findByDisplayValue} = render(
        <AppStateContext.Provider value={{appState: {runningProjects: [], activeProject: project}, dispatch}}>
          <ProjectWorkspaceHeader />
        </AppStateContext.Provider>
      );

      const editLink = await findByTitle('Edit');
      fireEvent.click(editLink);

      const textBox = await findByDisplayValue(project.title);
      fireEvent.change(textBox, {target: {value: ''}});
      fireEvent.blur(textBox);

      const button = await findByText('Update');
      expect(button.hasAttribute('disabled')).toBeTruthy();
    });

    it('should notify on error', async () => {
      const updateFnSpy = jest.spyOn(ProjectService.prototype, 'update').mockRejectedValue(new Error('mock error'));
      const notifiers: AppNotificationContextProps = createNotifers();

      const {findByText, findByTitle, findByDisplayValue} = render(
        <AppStateProviderWithProps appState={{runningProjects: [], activeProject: project}} {...{dispatch}}>
          <AppNotificationProviderWithProps {...{...notifiers}}>
            <ProjectWorkspaceHeader />
          </AppNotificationProviderWithProps>
        </AppStateProviderWithProps>
      );

      const editLink = await findByTitle('Edit');
      fireEvent.click(editLink);

      const updatedProjectTitle = `Updated ${project.title}`;
      const textBox = await findByDisplayValue(project.title);
      fireEvent.change(textBox, {target: {value: updatedProjectTitle}});

      const button = await findByText('Update');
      fireEvent.click(button);

      await wait(() => {
        expect(updateFnSpy).toHaveBeenCalledWith(project.id, {title: updatedProjectTitle});
        expect(notifiers.notifyError).toHaveBeenCalled();
      });
    });
  });

  describe('when transitioning project state', () => {
    it('should show no status text when project is not running', () => {
      const component = shallow(<ProjectWorkspaceHeader />);
      expect(component.find('.isStatus')).not.toExist();
    });

    [
      { match: "Starting", state: InterimProjectState.STARTING, verb: 'starting' },
      { match: "Stopping", state: InterimProjectState.STOPPING, verb: 'stopping' },
      { match: "Aborting", state: InterimProjectState.ABORTING, verb: 'aborting' }
    ].forEach(({
        match,
        state,
        verb
      }) => it(`should match "${match}..." status text when project is ${verb}`, () => {
      const component = mount(
        <AppStateContext.Provider
          value={{
            appState: {
              runningProjects: [],
              activeProject: { ...project, interimState: state },
            },
            dispatch,
          }}
        >
          <ProjectWorkspaceHeader />
        </AppStateContext.Provider>
      );

      expect(component.find('.isStatus').text()).toMatch(new RegExp(state, 'i'));
    }));

    it('should show "Running" status text when project is running', () => {
      const component = mount(
        <AppStateContext.Provider
          value={{
            appState: {
              runningProjects: [],
              activeProject: { ...project, running: true },
            },
            dispatch,
          }}
        >
          <ProjectWorkspaceHeader />
        </AppStateContext.Provider>
      );

      expect(component.find('.isStatus').text()).toMatch(new RegExp('running', 'i'));
    });
  });

  function createNotifers(notifiers?: {
    [K in keyof AppNotificationContextProps]?: AppNotificationContextProps[K]
  }): AppNotificationContextProps {
    const {notifySuccess, notifyInfo, notifyWarning, notifyError} = {...notifiers};
    return {
      notifySuccess: notifySuccess || jest.fn(),
      notifyInfo: notifyInfo || jest.fn(),
      notifyWarning: notifyWarning || jest.fn(),
      notifyError: notifyError || jest.fn()
    };
  }
});
