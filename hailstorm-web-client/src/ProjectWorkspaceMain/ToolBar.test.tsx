import React, { PropsWithChildren } from 'react';
import { shallow, mount } from 'enzyme';
import { ToolBar } from './ToolBar';
import { ButtonStateLookup, CheckedExecutionCycle } from './ControlPanel';
import { RunningProjectsContext } from '../RunningProjectsProvider';
import { ActiveProjectContext } from '../ProjectWorkspace';
import { Project, ExecutionCycle, InterimProjectState } from '../domain';
import { ProjectService, ReportService, JtlExportService } from '../api';
import { ModalProps } from '../Modal';
import { act } from '@testing-library/react';
import { SetRunningAction, SetInterimStateAction } from '../ProjectWorkspace/actions';

jest.mock('../Modal', () => {
  return {
    __esModule: true,
    Modal: (props: PropsWithChildren<ModalProps>) => (
      <div>{props.children}</div>
    )
  }
});

jest.mock('./JtlDownloadModal', () => {
  return {
    __esModule: true,
    JtlDownloadModal: () => (
      <div id="JtlDownloadModal"></div>
    )
  };
});

describe('<ToolBar />', () => {
  const setExecutionCycles = jest.fn();
  const setGridButtonStates = jest.fn();
  const setReloadGrid = jest.fn();
  const setViewTrash = jest.fn();
  const reloadReports = jest.fn();
  const reloadRunningProjects = jest.fn();
  const dispatch = jest.fn();

  const createToolBar: (attrs: {
    executionCycles: CheckedExecutionCycle[],
    buttonStates: ButtonStateLookup,
    viewTrash: boolean
  }) => JSX.Element = ({ executionCycles, buttonStates, viewTrash }) => (
    <ToolBar
      executionCycles={executionCycles}
      gridButtonStates={buttonStates}
      reloadReports={reloadReports}
      setExecutionCycles={setExecutionCycles}
      setGridButtonStates={setGridButtonStates}
      setReloadGrid={setReloadGrid}
      setViewTrash={setViewTrash}
      viewTrash={viewTrash}
    />
  );

  const createProject: (attrs?: {[K in keyof Project]?: Project[K]}) => Project = (attrs) => {
    return {id: 1, code: 'a', title: 'A', running: false, autoStop: false, ...attrs};
  };

  const createToolBarHierarchy: (attrs: {
    project: Project,
    buttonStates?: {[K in keyof ButtonStateLookup]?: ButtonStateLookup[K]},
    viewTrash?: boolean,
    executionCycles?: ExecutionCycle[]
  }) => JSX.Element = ({project, buttonStates, viewTrash}) => (
    <RunningProjectsContext.Provider value={{runningProjects: [], reloadRunningProjects}}>
      <ActiveProjectContext.Provider value={{project, dispatch}}>
        {createToolBar({
          executionCycles: [],
          buttonStates: {
            abort: true,
            stop: true,
            start: false,
            trash: false,
            export: true,
            report: true,
            ...buttonStates
          },
          viewTrash: viewTrash ? viewTrash : false
        })}
      </ActiveProjectContext.Provider>
    </RunningProjectsContext.Provider>
  );

  afterEach(() => {
    jest.resetAllMocks();
  });

  it('should render without crashing', () => {
    shallow(
      createToolBar({
        executionCycles: [],
        buttonStates: {
          abort: true,
          stop: true,
          start: false,
          trash: false,
          export: true,
          report: true
        },
        viewTrash: false
      })
    );
  });

  it('should set interim state on start', (done) => {
    const project: Project = createProject();
    const component = mount(createToolBarHierarchy({project}));
    const apiSpy = jest.spyOn(ProjectService.prototype, 'update').mockResolvedValue(undefined);
    component.find('button[name="start"]').simulate('click');
    expect(apiSpy).toBeCalled();
    setTimeout(() => {
      done();
      expect(setGridButtonStates).toBeCalled();
      expect(dispatch).toBeCalledTimes(3);
      expect(dispatch.mock.calls[0][0]).toBeInstanceOf(SetInterimStateAction);
      expect((dispatch.mock.calls[0][0] as SetInterimStateAction).payload).toEqual(InterimProjectState.STARTING);
      expect(dispatch.mock.calls[2][0]).toBeInstanceOf(SetRunningAction);
      expect((dispatch.mock.calls[2][0] as SetRunningAction).payload).toBeTruthy();
    }, 0);
  });

  it('should reload running projects on start', (done) => {
    const project: Project = createProject();
    const component = mount(createToolBarHierarchy({project}));
    const apiSpy = jest.spyOn(ProjectService.prototype, 'update').mockResolvedValue(undefined);
    component.find('button[name="start"]').simulate('click');
    expect(apiSpy).toBeCalled();
    setTimeout(() => {
      done();
      expect(reloadRunningProjects).toBeCalled();
      expect(dispatch).toBeCalled();
      expect(dispatch.mock.calls[2][0]).toBeInstanceOf(SetRunningAction);
      expect((dispatch.mock.calls[2][0] as SetRunningAction).payload).toBeTruthy();
    }, 0);
  });

  it('should reload running projects on stop', (done) => {
    const project: Project = createProject({running: true});
    const component = mount(createToolBarHierarchy({project, buttonStates: {stop: false}}));
    const apiSpy = jest.spyOn(ProjectService.prototype, 'update').mockResolvedValue(undefined);
    component.find('button[name="stop"]').simulate('click');
    expect(apiSpy).toBeCalled();
    setTimeout(() => {
      done();
      expect(reloadRunningProjects).toBeCalled();
      expect(dispatch).toBeCalled();
      expect(dispatch.mock.calls[2][0]).toBeInstanceOf(SetRunningAction);
      expect((dispatch.mock.calls[2][0] as SetRunningAction).payload).toBeFalsy();
    }, 0);
  });

  it('should reload running projects on abort', (done) => {
    const project: Project = createProject({running: true});
    const component = mount(createToolBarHierarchy({project, buttonStates: {abort: false}}));
    const apiSpy = jest.spyOn(ProjectService.prototype, 'update').mockResolvedValue(undefined);
    component.find('button[name="abort"]').simulate('click');
    expect(apiSpy).toBeCalled();
    setTimeout(() => {
      done();
      expect(reloadRunningProjects).toBeCalled();
      expect(dispatch).toBeCalled();
      expect(dispatch.mock.calls[2][0]).toBeInstanceOf(SetRunningAction);
      expect((dispatch.mock.calls[2][0] as SetRunningAction).payload).toBeFalsy();
    }, 0);
  });

  it('should open trash view on View Trash', (done) => {
    const project: Project = createProject();
    const component = mount(createToolBarHierarchy({project}));
    component.find('button[name="trash"]').simulate('click');
    setTimeout(() => {
      done();
      expect(setGridButtonStates).toBeCalled();
      const nextButtonStates = setGridButtonStates.mock.calls[0][0] as ButtonStateLookup;
      expect(nextButtonStates.stop).toBeTruthy();
      expect(nextButtonStates.abort).toBeTruthy();
      expect(nextButtonStates.start).toBeTruthy();
    }, 0);
  });

  it('should restore button state on closing trash view', (done) => {
    const project: Project = createProject({running: true});
    const component = mount(createToolBarHierarchy({project, buttonStates: {start: true, stop: false, abort: false}, viewTrash: true}));
    component.find('button[name="trash"]').simulate('click');
    setTimeout(() => {
      done();
      expect(setGridButtonStates).toBeCalled();
      const nextButtonStates = setGridButtonStates.mock.calls[0][0] as ButtonStateLookup;
      expect(nextButtonStates.stop).toBeFalsy();
      expect(nextButtonStates.abort).toBeFalsy();
      expect(nextButtonStates.start).toBeTruthy();
    }, 0);
  });

  it('should report results on Report', (done) => {
    const project: Project = createProject();
    const component = mount(createToolBarHierarchy({project, buttonStates: {report: false}}));
    const apiSpy = jest.spyOn(ReportService.prototype, 'create').mockResolvedValue(undefined);
    component.find('button[name="report"]').simulate('click');
    expect(apiSpy).toBeCalled();
    setTimeout(() => {
      done();
      expect(reloadReports).toBeCalled();
    }, 0);
  });

  it('should export results on Export', (done) => {
    const project: Project = createProject();
    const component = mount(createToolBarHierarchy({project, buttonStates: {export: false}}));
    const apiSpy = jest.spyOn(JtlExportService.prototype, 'create').mockResolvedValue({title: 'A', url: 'B'});
    act(() => {
      component.find('button[name="export"]').simulate('click');
    });
    expect(apiSpy).toBeCalled();
    setTimeout(() => {
      done();
      expect(component).toContainExactlyOneMatchingElement('#JtlDownloadModal');
    }, 0);
  });
});
