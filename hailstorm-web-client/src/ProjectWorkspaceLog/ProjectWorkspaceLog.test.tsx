import React from 'react';
import { mount } from 'enzyme';
import { empty, Observable, of, Subscription, Subject } from 'rxjs';
import { AppStateContext } from '../appStateContext';
import { LogEvent, Project } from '../domain';
import { LogStream } from '../log-stream';
import { ProjectWorkspaceLog } from './ProjectWorkspaceLog';

describe('<ProjectWorkspaceLog />', () => {
  let logStreamSpy: jest.SpyInstance<Observable<LogEvent>, []>;
  const log$Factory = (project: Project) => of(
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

  beforeEach(() => {
    window.getComputedStyle = jest.fn().mockReturnValue({lineHeight: 100});
  });

  afterEach(() => {
    jest.resetAllMocks();
    if (logStreamSpy) logStreamSpy.mockRestore();
  });

  it('should render without crashing', () => {
    const project: Project = {id: 1, code: 'a', title: 'A', running: true, autoStop: false};
    logStreamSpy = jest.spyOn(LogStream, '_logSource').mockReturnValue(empty());
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
                       .mockReturnValueOnce(empty());

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
                       .mockReturnValueOnce(empty());

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
      expect(component).toContainMatchingElements(1, '.logBox div');
    }, 0);
  });
});
