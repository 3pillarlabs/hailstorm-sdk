import React from 'react';
import { mount } from 'enzyme';
import { Observable, of, Subscription, Subject, EMPTY } from 'rxjs';
import { AppStateContext } from '../appStateContext';
import { LogEvent, Project } from '../domain';
import { LogStream } from '../log-stream';
import { ProjectWorkspaceLog } from './ProjectWorkspaceLog';
import { AppNotificationContextProps } from '../app-notifications';
import { AppNotificationProviderWithProps } from '../AppNotificationProvider';
import { AppStateProviderWithProps } from '../AppStateProvider';
import { render, wait } from '@testing-library/react';

describe('<ProjectWorkspaceLog />', () => {
  let logStreamSpy: jest.SpyInstance<Observable<LogEvent>, []>;
  const log$Factory: (project: Project) => Observable<LogEvent> = (project) => of(
    {
      projectCode: project.code,
      timestamp: 1565759983,
      priority: 2,
      level: "info",
      message: "Starting Tests...",
    },
    {
      projectCode: project.code,
      timestamp: 1565760004,
      priority: 2,
      level: "info",
      message: `Creating Cluster in us-east-1...`,
    },
    {
      projectCode: project.code,
      timestamp: 1565780014,
      priority: 2,
      level: "info",
      message: `Creating Cluster in us-west-1...`,
    }
  );

  function withNotificationContext(
    component: JSX.Element,
    notifiers?: {
      [K in keyof AppNotificationContextProps]?: AppNotificationContextProps[K]
    }
  ) {

    const {notifySuccess, notifyInfo, notifyWarning, notifyError} = {...notifiers};
    return (
      <AppNotificationProviderWithProps
        notifySuccess={notifySuccess || jest.fn()}
        notifyInfo={notifyInfo || jest.fn()}
        notifyWarning={notifyWarning || jest.fn()}
        notifyError={notifyError || jest.fn()}
      >
        {component}
      </AppNotificationProviderWithProps>
    )
  }

  beforeEach(() => {
    window.getComputedStyle = jest.fn().mockReturnValue({lineHeight: 100});
  });

  afterEach(() => {
    jest.resetAllMocks();
    if (logStreamSpy) logStreamSpy.mockRestore();
  });

  it('should render without crashing', () => {
    const project: Project = {id: 1, code: 'a', title: 'A', running: true, autoStop: false};
    logStreamSpy = jest.spyOn(LogStream, '_logSource').mockReturnValue(EMPTY);
    const component = mount(
      <AppStateContext.Provider
        value={{
          appState: { activeProject: project, runningProjects: [project] },
          dispatch: jest.fn(),
        }}
      >
        <ProjectWorkspaceLog />
      </AppStateContext.Provider>
    );

    component.update();
    expect(logStreamSpy).toHaveBeenCalled();
  });

  it('should update logs as they are received', (done) => {
    const project: Project = {id: 1, code: 'a', title: 'A', running: true, autoStop: false};
    logStreamSpy = jest.spyOn(LogStream, "_logSource").mockImplementation(() => log$Factory(project));
    const component = mount(
      <AppStateContext.Provider
        value={{
          appState: { activeProject: project, runningProjects: [project] },
          dispatch: jest.fn(),
        }}
      >
        <ProjectWorkspaceLog />
      </AppStateContext.Provider>
    );

    component.update();
    setTimeout(() => {
      done();
      expect(logStreamSpy).toHaveBeenCalled();
      expect(component).toContainMatchingElements(3, '.logBox div');
    }, 0);
  });

  it('should unsubscribe on component unmount', (done) => {
    const project: Project = {id: 1, code: 'a', title: 'A', running: true, autoStop: false};
    const subscription = new Subscription();
    const subscriptionSpy = jest.spyOn(subscription, 'unsubscribe');
    const observable = new Observable<LogEvent>();
    jest.spyOn(observable, 'subscribe').mockReturnValue(subscription);
    const logObserveSpy = jest.spyOn(LogStream, 'observe').mockReturnValue(observable);
    const component = mount(
      <AppStateContext.Provider
        value={{
          appState: { activeProject: project, runningProjects: [project] },
          dispatch: jest.fn(),
        }}
      >
        <ProjectWorkspaceLog />
      </AppStateContext.Provider>
    );

    component.update();
    component.unmount();
    setTimeout(() => {
      done();
      logObserveSpy.mockRestore();
      expect(subscriptionSpy).toHaveBeenCalled();
    }, 0);
  });

  it('should not show debug messages when verbose is off', (done) => {
    const project: Project = {id: 1, code: 'a', title: 'A', running: true, autoStop: false};
    logStreamSpy = jest.spyOn(LogStream, '_logSource').mockImplementation(() => of(
      {projectCode: project.code, timestamp: 1565759983, priority: 2, level: 'debug', message: 'Starting Tests...'},
    ));

    const component = mount(
      <AppStateContext.Provider
        value={{
          appState: { activeProject: project, runningProjects: [project] },
          dispatch: jest.fn(),
        }}
      >
        <ProjectWorkspaceLog />
      </AppStateContext.Provider>
    );

    component.update();
    expect(logStreamSpy).toHaveBeenCalled();
    setTimeout(() => {
      done();
      expect(component).toContainMatchingElements(0, '.logBox div');
    }, 0);
  });

  it('should show debug messages when verbose is on', () => {
    const project: Project = {id: 1, code: 'a', title: 'A', running: true, autoStop: false};
    const source = new Subject<LogEvent>();
    logStreamSpy = jest.spyOn(LogStream, "_logSource").mockReturnValue(source);
    const component = mount(
      <AppStateContext.Provider
        value={{
          appState: { activeProject: project, runningProjects: [project] },
          dispatch: jest.fn(),
        }}
      >
        <ProjectWorkspaceLog />
      </AppStateContext.Provider>
    );

    component.update();
    component.simulate('mouseenter');
    component.find('LogOptions').find('input[type="checkbox"]').simulate('change', {target: {checked: true}});
    component.update();
    expect(component.find('LogOptions')).toHaveProp('verbose', true);
    source.next({
      projectCode: project.code,
      timestamp: 1565759983,
      priority: 2,
      level: "debug",
      message: "Starting Tests...",
    });

    component.update();
    expect(logStreamSpy).toHaveBeenCalled();
    expect(component).toContainMatchingElements(1, '.logBox div');
  });

  it('should keep all messages when scroll limit is increased', (done) => {
    const project: Project = {id: 1, code: 'a', title: 'A', running: true, autoStop: false};
    logStreamSpy = jest.spyOn(LogStream, "_logSource")
                       .mockReturnValueOnce(log$Factory(project))
                       .mockReturnValueOnce(EMPTY);

    const component = mount(
      <AppStateContext.Provider
        value={{
          appState: { activeProject: project, runningProjects: [project] },
          dispatch: jest.fn(),
        }}
      >
        <ProjectWorkspaceLog scrollLimit={5} />
      </AppStateContext.Provider>
    );

    component.update();
    expect(logStreamSpy).toHaveBeenCalled();
    setTimeout(() => {
      done();
      expect(component).toContainMatchingElements(3, '.logBox div');
      component.simulate('mouseenter');
      component.find('LogOptions').find('select').simulate('change', {target: {value: 10}});
      component.update();
      expect(component).toContainMatchingElements(3, '.logBox div');
    }, 0);
  });

  it('should remove excess messages when scroll limit is decreased', (done) => {
    const project: Project = {id: 1, code: 'a', title: 'A', running: true, autoStop: false};
    logStreamSpy = jest.spyOn(LogStream, "_logSource")
                       .mockReturnValueOnce(log$Factory(project))
                       .mockReturnValueOnce(EMPTY);

    const component = mount(
      <AppStateContext.Provider
        value={{
          appState: { activeProject: project, runningProjects: [project] },
          dispatch: jest.fn(),
        }}
      >
        <ProjectWorkspaceLog scrollLimit={5} />
      </AppStateContext.Provider>
    );

    component.update();
    expect(logStreamSpy).toHaveBeenCalled();
    setTimeout(() => {
      done();
      expect(component).toContainMatchingElements(3, '.logBox div');
      component.simulate('mouseenter');
      component.find('LogOptions').find('select').simulate('change', {target: {value: 2}});
      component.update();
      expect(component).toContainMatchingElements(2, '.logBox div');
    }, 0);
  });

  it('should remove excess lines than scroll limit', (done) => {
    const project: Project = {id: 1, code: 'a', title: 'A', running: true, autoStop: false};
    const source = new Subject<LogEvent>();
    logStreamSpy = jest.spyOn(LogStream, "_logSource").mockReturnValue(source);
    const component = mount(
      <AppStateContext.Provider
        value={{
          appState: { activeProject: project, runningProjects: [project] },
          dispatch: jest.fn(),
        }}
      >
        <ProjectWorkspaceLog scrollLimit={2} />
      </AppStateContext.Provider>
    );

    component.update();

    log$Factory(project).forEach((logEvent) => source.next(logEvent));
    expect(logStreamSpy).toHaveBeenCalled();
    setTimeout(() => {
      done();
      component.update();
      expect(component).toContainMatchingElements(2, '.logBox div');
      expect(component.find('.logBox div').at(1).text()).toMatch(/Creating Cluster in us-west-1/);
    }, 0);
  });

  it('should clear messages', (done) => {
    const project: Project = {id: 1, code: 'a', title: 'A', running: true, autoStop: false};
    logStreamSpy = jest.spyOn(LogStream, '_logSource').mockImplementation(() => of(
      {projectCode: project.code, timestamp: 1565759983, priority: 2, level: 'info', message: 'Starting Tests...'},
    ));

    const component = mount(
      <AppStateContext.Provider
        value={{
          appState: { activeProject: project, runningProjects: [] },
          dispatch: jest.fn(),
        }}
      >
        <ProjectWorkspaceLog />
      </AppStateContext.Provider>
    );

    component.update();
    expect(logStreamSpy).toHaveBeenCalled();
    setTimeout(() => {
      done();
      component.simulate('mouseenter');
      component.find('LogOptions').find('button').at(1).simulate('click');
      expect(component).toContainMatchingElements(0, '.logBox div');
    }, 0);
  });

  it('should show error messages', (done) => {
    const project: Project = {id: 1, code: 'a', title: 'A', running: true, autoStop: false};
    logStreamSpy = jest.spyOn(LogStream, '_logSource').mockImplementation(() => of(
      {projectCode: project.code, timestamp: 1565759983, priority: 3, level: 'error', message: 'Some error'},
    ));

    const notifyError = jest.fn();
    const component = mount(
      withNotificationContext(
        (
          <AppStateProviderWithProps
            appState={{ activeProject: project, runningProjects: [project] }}
            dispatch={jest.fn()}
          >
            <ProjectWorkspaceLog />
          </AppStateProviderWithProps>
        ), {
          notifyError
        }
      )
    );

    component.update();
    expect(logStreamSpy).toHaveBeenCalled();
    setTimeout(() => {
      done();
      expect(component).toContainMatchingElements(1, '.logBox div');
      expect(notifyError).toHaveBeenCalled();
    }, 0);
  });

  it('should show warning messages', (done) => {
    const project: Project = {id: 1, code: 'a', title: 'A', running: true, autoStop: false};
    logStreamSpy = jest.spyOn(LogStream, '_logSource').mockImplementation(() => of(
      {projectCode: project.code, timestamp: 1565759983, priority: 2, level: 'warn', message: 'A warning'},
    ));

    const notifyWarning = jest.fn();
    const component = mount(
      withNotificationContext(
        (
          <AppStateProviderWithProps
            appState={{ activeProject: project, runningProjects: [project] }}
            dispatch={jest.fn()}
          >
            <ProjectWorkspaceLog />
          </AppStateProviderWithProps>
        ), {
          notifyWarning
        }
      )
    );

    component.update();
    expect(logStreamSpy).toHaveBeenCalled();
    setTimeout(() => {
      done();
      expect(component).toContainMatchingElements(1, '.logBox div');
      expect(notifyWarning).toHaveBeenCalled();
    }, 0);
  });

  describe('on subscription error', () => {
    const project: Project = {id: 1, code: 'a', title: 'A', running: true, autoStop: false};
    let subject: Subject<LogEvent>;
    let notifyError: jest.Mock<any, any>;
    let notifyWarning: jest.Mock<any, any>;
    let unmount: () => boolean;

    beforeEach(async () => {
      notifyError = jest.fn();
      notifyWarning = jest.fn();
      subject = new Subject<LogEvent>();
      const spy = jest.spyOn(LogStream, "observe").mockReturnValue(subject);
      const result = render(
        withNotificationContext((
          <AppStateContext.Provider
          value={{
            appState: { activeProject: project, runningProjects: [project] },
            dispatch: jest.fn(),
          }}
        >
          <ProjectWorkspaceLog />
        </AppStateContext.Provider>
        ), {notifyError, notifyWarning})
      );

      unmount = result.unmount;
      await wait(() => {
        expect(spy).toHaveBeenCalled();
      });
    });

    afterEach(() => {
      unmount();
    })

    it('should notify of an error object', async () => {
      subject.error(new Error('mock error'));
      await wait(() => {
        expect(notifyError).toBeCalled();
      });
    });

    it('should notify of an error message', async () => {
      subject.error('mock error message');
      await wait(() => {
        expect(notifyWarning).toBeCalled();
      });
    });

    it('should notify of an unknown reason type', async () => {
      subject.error({reason: '', of: []});
      await wait(() => {
        expect(notifyWarning).toBeCalled();
      });
    });
  });
});
