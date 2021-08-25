import React from 'react';
import { shallow, mount, ReactWrapper } from 'enzyme';
import { TerminateProject } from './TerminateProject';
import { Project, InterimProjectState } from '../domain';
import { ProjectService } from "../services/ProjectService";
import { act } from '@testing-library/react';
import { AppStateProviderWithProps } from '../AppStateProvider';
import { AppNotificationProviderWithProps } from '../AppNotificationProvider';
import { AppNotificationContextProps } from '../app-notifications';

jest.mock('../Modal', () => ({
  __esModule: true,
  Modal: (props: React.PropsWithChildren<{isActive: boolean}>) => (
    props.isActive ? <div id="modal">{props.children}</div> : null
  )
}));

describe('<TerminateProject />', () => {
  let project:Project;

  const buildComponent = ({
    dispatch,
    projectAttrs,
    notifiers
  }: {
    dispatch?: any;
    projectAttrs?: {[K in keyof Project]?: Project[K]};
    notifiers?: {[K in keyof AppNotificationContextProps]?: AppNotificationContextProps[K]}
  } = {}) => {
    project = {
      id: 1,
      code: 'a',
      title: 'A',
      autoStop: false,
      running: false,
      ...(projectAttrs || {})
    };

    const {notifySuccess, notifyInfo, notifyWarning, notifyError} = {...notifiers};
    return (
      <AppStateProviderWithProps
        appState={{ activeProject: project, runningProjects: [] }}
        dispatch={dispatch || jest.fn()}
      >
        <AppNotificationProviderWithProps
          notifySuccess={notifySuccess || jest.fn()}
          notifyError={notifyError || jest.fn()}
          notifyInfo={notifyInfo || jest.fn()}
          notifyWarning={notifyWarning || jest.fn()}
        >
          <TerminateProject />
        </AppNotificationProviderWithProps>
      </AppStateProviderWithProps>
    );
  };

  afterEach(() => jest.resetAllMocks());

  it('should render without crashing', () => {
    shallow(buildComponent());
  });

  it('should be disabled when the project is already terminating', () => {
    const component = mount(buildComponent({projectAttrs: {interimState: InterimProjectState.TERMINATING}}));
    expect(component.find('button')).toBeDisabled();
  });

  it('should invoke modal confirmation', () => {
    const component = mount(buildComponent());
    act(() => {
      component.find('button').simulate('click');
    });
    component.update();
    expect(component.find('#modal .modal')).toExist();
  });

  it('should do nothing if modal is not confirmed', () => {
      let apiSpy = jest.spyOn(ProjectService.prototype, 'update').mockRejectedValue(undefined);
      const dispatch = jest.fn();
      const component = mount(buildComponent({dispatch}))
      act(() => {
        component.find('button').simulate('click');
      });

      component.update();
      component.find('a.is-primary').simulate('click');
      expect(dispatch).not.toBeCalled();
      expect(apiSpy).not.toBeCalled();
  });

  describe('when project is running', () => {
    let component: ReactWrapper | null = null;
    beforeEach(() => {
      component = mount(buildComponent({projectAttrs: {running: true}}));
      act(() => {
        component!.find('button').simulate('click');
      });

      component.update();
    });

    it('should disable modal confirmation', () => {
      expect(component!.find('button.is-danger')).toBeDisabled();
    });

    it('should enable modal confirmation if user acknowledges data loss', () => {
      act(() => {
        component!.find('input[type="checkbox"]').simulate('change');
      });

      component!.update();
      expect(component!.find('button.is-danger')).not.toBeDisabled();
    });
  });

  describe('when modal is confirmed', () => {
    it('should set interim state before api invocation', async (done) => {
      const apiUpdateSpy = jest.spyOn(ProjectService.prototype, 'update').mockResolvedValue(204);
      const apiGetPromise = Promise.resolve<Project>(project);
      const apiGetSpy = jest.spyOn(ProjectService.prototype, 'get').mockResolvedValueOnce(apiGetPromise);
      const dispatch = jest.fn();
      const component = mount(buildComponent({dispatch}));
      act(() => {
        component.find('button').simulate('click');
      });

      component.update();
      component.find('button.is-danger').simulate('click');
      expect(dispatch).toBeCalled();
      expect(apiUpdateSpy).toBeCalled();
      await apiGetPromise;
      setTimeout(() => {
        done();
        expect(apiGetSpy).toBeCalled();
      }, 0);
    });

    it('should notify of an error', (done) => {
      const failedPromise = Promise.reject(new Error('mock error'));
      const apiUpdateSpy = jest.spyOn(ProjectService.prototype, 'update').mockReturnValue(failedPromise);
      const notifyError = jest.fn();
      const component = mount(buildComponent({notifiers: {notifyError}}));
      act(() => {
        component.find('button').simulate('click');
      });

      component.update();
      component.find('button.is-danger').simulate('click');
      expect(apiUpdateSpy).toBeCalled();
      setTimeout(() => {
        done();
        expect(notifyError).toBeCalled();
      }, 0);
    });
  });
});
