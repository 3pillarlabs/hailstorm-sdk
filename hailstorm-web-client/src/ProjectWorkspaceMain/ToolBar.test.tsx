import React, { PropsWithChildren } from 'react';
import { shallow, mount } from 'enzyme';
import { ToolBar } from './ToolBar';
import { ButtonStateLookup, CheckedExecutionCycle } from './ControlPanel';
import { Project, ExecutionCycle, InterimProjectState } from '../domain';
import { JtlExportService } from "../services/JtlExportService";
import { ReportService } from "../services/ReportService";
import { ProjectService } from "../services/ProjectService";
import { ModalProps } from '../Modal';
import { act } from '@testing-library/react';
import { SetRunningAction, SetInterimStateAction, UnsetInterimStateAction } from '../ProjectWorkspace/actions';
import { AppStateContext } from '../appStateContext';
import { ExecutionCycleService } from '../services/ExecutionCycleService';

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
  beforeEach(() => {
    jest.resetAllMocks();
  });

  const setExecutionCycles = jest.fn();
  const setGridButtonStates = jest.fn();
  const setReloadGrid = jest.fn();
  const setViewTrash = jest.fn();
  const reloadReports = jest.fn();
  const dispatch = jest.fn();

  const createToolBar: (attrs: {
    executionCycles: CheckedExecutionCycle[],
    buttonStates: ButtonStateLookup,
    viewTrash: boolean,
    statusCheckInterval?: number,
  }) => JSX.Element = ({ executionCycles, buttonStates, viewTrash, statusCheckInterval }) => (
    <ToolBar
      executionCycles={executionCycles}
      gridButtonStates={buttonStates}
      reloadReports={reloadReports}
      setExecutionCycles={setExecutionCycles}
      setGridButtonStates={setGridButtonStates}
      setReloadGrid={setReloadGrid}
      setViewTrash={setViewTrash}
      viewTrash={viewTrash}
      statusCheckInterval={statusCheckInterval}
    />
  );

  const createProject: (attrs?: {[K in keyof Project]?: Project[K]}) => Project = (attrs) => {
    return {id: 1, code: 'a', title: 'A', running: false, autoStop: false, ...attrs};
  };

  const createToolBarHierarchy: (attrs: {
    project: Project,
    buttonStates?: {[K in keyof ButtonStateLookup]?: ButtonStateLookup[K]},
    viewTrash?: boolean,
    executionCycles?: CheckedExecutionCycle[],
    statusCheckInterval?: number
  }) => JSX.Element = ({project, buttonStates, viewTrash, statusCheckInterval, executionCycles}) => (

    <AppStateContext.Provider value={{appState: {runningProjects: [], activeProject: project}, dispatch}}>
      {createToolBar({
        executionCycles: executionCycles || [],
        buttonStates: {
          abort: true,
          stop: true,
          start: false,
          trash: false,
          export: true,
          report: true,
          ...buttonStates
        },
        viewTrash: viewTrash ? viewTrash : false,
        statusCheckInterval: statusCheckInterval
      })}
    </AppStateContext.Provider>
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
    const projectUpdateSpy = jest.spyOn(ProjectService.prototype, 'update').mockResolvedValue(204);
    const projectGetSpy = jest.spyOn(ProjectService.prototype, 'get').mockResolvedValue(createProject({running: true}));
    component.find('button[name="start"]').simulate('click');
    expect(projectUpdateSpy).toBeCalled();
    setTimeout(() => {
      done();
      expect(projectGetSpy).toBeCalled();
      expect(setGridButtonStates).toBeCalled();
      expect(dispatch).toBeCalledTimes(4);
      expect(dispatch.mock.calls[0][0]).toBeInstanceOf(SetInterimStateAction);
      expect((dispatch.mock.calls[0][0] as SetInterimStateAction).payload).toEqual(InterimProjectState.STARTING);
      expect(dispatch.mock.calls[3][0]).toBeInstanceOf(SetRunningAction);
      expect((dispatch.mock.calls[3][0] as SetRunningAction).payload).toBeTruthy();
    }, 0);
  });

  it('should reload running projects on start', (done) => {
    const project: Project = createProject();
    const component = mount(createToolBarHierarchy({project}));
    const projectUpdateSpy = jest.spyOn(ProjectService.prototype, 'update').mockResolvedValue(204);
    const projectGetSpy = jest.spyOn(ProjectService.prototype, 'get').mockResolvedValue(createProject({running: true}));
    component.find('button[name="start"]').simulate('click');
    expect(projectUpdateSpy).toBeCalled();
    setTimeout(() => {
      done();
      expect(projectGetSpy).toBeCalled();
      expect(dispatch).toBeCalled();
      expect(dispatch.mock.calls[3][0]).toBeInstanceOf(SetRunningAction);
      expect((dispatch.mock.calls[3][0] as SetRunningAction).payload).toBeTruthy();
    }, 0);
  });

  it('should reload running projects on stop', (done) => {
    const project: Project = createProject({running: true});
    const component = mount(createToolBarHierarchy({project, buttonStates: {stop: false}}));
    const projectUpdateSpy = jest.spyOn(ProjectService.prototype, 'update').mockResolvedValue(204);
    const projectGetSpy = jest.spyOn(ProjectService.prototype, 'get').mockResolvedValue(createProject({running: true}));
    component.find('button[name="stop"]').simulate('click');
    expect(projectUpdateSpy).toBeCalled();
    setTimeout(() => {
      done();
      expect(projectGetSpy).toBeCalled();
      expect(dispatch).toBeCalled();
      expect(dispatch.mock.calls[3][0]).toBeInstanceOf(SetRunningAction);
      expect((dispatch.mock.calls[3][0] as SetRunningAction).payload).toBeFalsy();
    }, 0);
  });

  it('should reload running projects on abort', (done) => {
    const project: Project = createProject({running: true});
    const component = mount(createToolBarHierarchy({project, buttonStates: {abort: false}}));
    const projectUpdateSpy = jest.spyOn(ProjectService.prototype, 'update').mockResolvedValue(204);
    const projectGetSpy = jest.spyOn(ProjectService.prototype, 'get').mockResolvedValue(createProject({running: false}));
    component.find('button[name="abort"]').simulate('click');
    expect(projectUpdateSpy).toBeCalled();
    setTimeout(() => {
      done();
      expect(projectGetSpy).toBeCalled();
      expect(dispatch).toBeCalled();
      expect(dispatch.mock.calls[3][0]).toBeInstanceOf(SetRunningAction);
      expect((dispatch.mock.calls[3][0] as SetRunningAction).payload).toBeFalsy();
    }, 0);
  });

  it('should open trash view on View Trash', (done) => {
    const project: Project = createProject();
    const component = mount(
      createToolBarHierarchy({
        project,
        executionCycles: [{id: 201, projectId: 1, startedAt: new Date(), checked: false}]
      })
    );

    component.find('button[name="trash"]').simulate('click');
    setTimeout(() => {
      done();
      expect(setGridButtonStates).toBeCalled();
      const nextButtonStates = setGridButtonStates.mock.calls[0][0] as ButtonStateLookup;
      expect(nextButtonStates.stop).toBeTruthy();
      expect(nextButtonStates.abort).toBeTruthy();
      expect(nextButtonStates.start).toBeTruthy();
      expect(setExecutionCycles).toHaveBeenCalled();
    }, 0);
  });

  it('should restore button state on closing trash view', (done) => {
    const project: Project = createProject({running: true});
    const component = mount(createToolBarHierarchy({
      project,
      buttonStates: {start: true, stop: false, abort: false},
      viewTrash: true
    }));
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
    const component = mount(createToolBarHierarchy({
      project,
      buttonStates: {
        report: false
      },
      executionCycles: [{id: 201, projectId: 1, startedAt: new Date(), checked: true}]
    }));

    const apiSpy = jest.spyOn(ReportService.prototype, 'create').mockResolvedValue({
      id: 200,
      projectId: 1,
      title: 'a',
      uri: 'http://hailstorm.fs/reports/1/223/a.docx'
    });

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

  it('should start status checks if project is autoStop and running', (done) => {
    const exCycle: ExecutionCycle = {id: 20, projectId: 1, startedAt: new Date(), threadsCount: 20};
    const projectApiPromise = Promise.resolve(200);
    const projectApiSpy = jest.spyOn(ProjectService.prototype, 'update').mockReturnValue(projectApiPromise);
    jest
      .spyOn(ExecutionCycleService.prototype, 'get')
      .mockResolvedValueOnce({ noRunningTests: false, ...exCycle })
      .mockResolvedValueOnce({ noRunningTests: false, ...exCycle })
      .mockResolvedValueOnce({ noRunningTests: true, ...exCycle });
    const project = createProject({running: true, autoStop: true});
    mount(createToolBarHierarchy({project, statusCheckInterval: 1}));
    setTimeout(() => {
      done();
      expect(projectApiSpy).toHaveBeenCalled();
    }, 50);
  });

  it('should unset interim status on action error', (done) => {
    const project: Project = createProject();
    const component = mount(createToolBarHierarchy({project}));
    const projectUpdateSpy = jest.spyOn(ProjectService.prototype, 'update').mockRejectedValue(new Error('mock error'));
    component.find('button[name="start"]').simulate('click');
    expect(projectUpdateSpy).toBeCalled();
    setTimeout(() => {
      done();
      expect(dispatch).toBeCalled();
      expect(dispatch.mock.calls[1][0]).toBeInstanceOf(UnsetInterimStateAction);
    }, 0);
  });

  it('should abort interim status checks if a status check fails', (done) => {
    const projectApiPromise = Promise.resolve(200);
    const projectApiSpy = jest.spyOn(ProjectService.prototype, 'update').mockReturnValue(projectApiPromise);
    jest
      .spyOn(ExecutionCycleService.prototype, 'get')
      .mockRejectedValue(new Error('mock error'));
    const project = createProject({running: true, autoStop: true});
    mount(createToolBarHierarchy({project, statusCheckInterval: 1}));
    setTimeout(() => {
      done();
      expect(projectApiSpy).not.toHaveBeenCalled();
    }, 10);
  });

  it('should abort interim status checks if component is unloaded', (done) => {
    const exCycle: ExecutionCycle = {id: 20, projectId: 1, startedAt: new Date(), threadsCount: 20};
    const projectApiPromise = Promise.resolve(200);
    const projectApiSpy = jest.spyOn(ProjectService.prototype, 'update').mockReturnValue(projectApiPromise);
    jest
      .spyOn(ExecutionCycleService.prototype, 'get')
      .mockResolvedValue({ noRunningTests: false, ...exCycle });
    const project = createProject({running: true, autoStop: true});
    const component = mount(createToolBarHierarchy({project, statusCheckInterval: 1}));
    component.unmount();
    setTimeout(() => {
      done();
      expect(projectApiSpy).not.toHaveBeenCalled();
    }, 10);
  });
});
