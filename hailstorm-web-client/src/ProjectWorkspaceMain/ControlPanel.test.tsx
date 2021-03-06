import React from 'react';
import { shallow, ShallowWrapper, mount, ReactWrapper } from 'enzyme';
import { ControlPanel, ButtonStateLookup } from './ControlPanel';
import { InterimProjectState, Project } from '../domain';
import { ToolBarProps } from './ToolBar';
import { ExecutionCycleGridProps } from './ExecutionCycleGrid';

jest.mock('./ToolBar', () => {
  return {
    __esModule: true,
    ToolBar: (props: ToolBarProps) => (
      <div id="toolBar">
        <button id="stop" disabled={props.gridButtonStates.stop}>Stop</button>
        <button id="abort" disabled={props.gridButtonStates.abort}>Abort</button>
        <button id="start" disabled={props.gridButtonStates.start}>Start</button>
      </div>
    )
  }
});

jest.mock('./ExecutionCycleGrid', () => {
  return {
    __esModule: true,
    ExecutionCycleGrid: (_props: ExecutionCycleGridProps) => (
      <div id="executionCycleGrid">
      </div>
    )
  }
});

describe('<ControlPanel />', () => {

  const projectFixture: (attrs: {autoStop: boolean, running: boolean}) => Project = ({autoStop, running}) => {
    return {id: 1, code: 'a', title: 'A', autoStop, running};
  }

  const componentFixture: (project: Project) => ReactWrapper = (project) => {
    return mount(
      <ControlPanel reloadReports={jest.fn()} {...{project}} setWaitingForReport={jest.fn} dispatch={jest.fn()}/>
    );
  }

  afterEach(() => {
    jest.resetAllMocks();
  });

  it('should render without crashing', () => {
    shallow(
      <ControlPanel
        reloadReports={jest.fn()}
        project={projectFixture({autoStop: true, running: false})}
        setWaitingForReport={jest.fn()}
        dispatch={jest.fn()}
      />
    );
  });

  describe('initial state', () => {
    let component: ShallowWrapper | null = null;

    beforeEach(() => {
      component = shallow(
        <ControlPanel
          reloadReports={jest.fn()}
          project={projectFixture({autoStop: true, running: false})}
          setWaitingForReport={jest.fn()}
          dispatch={jest.fn()}
        />
      );
    });

    it('should enable view trash button', () => {
      expect(component!.find('ExecutionCycleGrid')).toHaveProp('viewTrash', false);
    });

    it('should disable report button', () => {
      const buttons = component!.find('ExecutionCycleGrid').prop('gridButtonStates') as ButtonStateLookup;
      expect(buttons.report).toBeTruthy();
    });

    it('should disable export button', () => {
      const buttons = component!.find('ExecutionCycleGrid').prop('gridButtonStates') as ButtonStateLookup;
      expect(buttons.export).toBeTruthy();
    });
  });

  describe('when project has tests running', () => {
    it('should enable stop button if tests need to stopped', () => {
      const project = projectFixture({autoStop: false, running: true});
      const button = componentFixture(project).find('#toolBar').find('button#stop');
      expect(button).not.toBeDisabled();
    });

    it('should disable stop button if tests auto-stop', () => {
      const project = projectFixture({autoStop: true, running: true});
      const button = componentFixture(project).find('#toolBar').find('button#stop');
      expect(button).toBeDisabled();
    });

    it('should enable abort button', () => {
      const project = projectFixture({autoStop: true, running: true});
      const button = componentFixture(project).find('#toolBar').find('button#abort');
      expect(button).not.toBeDisabled();
    });

    it('should disable start button', () => {
      const project = projectFixture({autoStop: true, running: true});
      const button = componentFixture(project).find('#toolBar').find('button#start');
      expect(button).toBeDisabled();
    });
  });

  describe('when project does not have tests running', () => {
    it('should enable only start button', () => {
      const project = projectFixture({autoStop: true, running: false});
      const toolBarWrapper = componentFixture(project).find('#toolBar');
      expect(toolBarWrapper.find('button#start')).not.toBeDisabled();
      expect(toolBarWrapper.find('button#stop')).toBeDisabled();
      expect(toolBarWrapper.find('button#abort')).toBeDisabled();
    });
  });

  describe('when project has any interim action ongoing', () => {
    it('should disable start, stop and abort buttons', () => {
      const project = projectFixture({autoStop: false, running: false});
      project.interimState = InterimProjectState.STARTING;
      const toolBarWrapper = componentFixture(project).find('#toolBar');
      expect(toolBarWrapper.find('button#start')).toBeDisabled();
      expect(toolBarWrapper.find('button#stop')).toBeDisabled();
      expect(toolBarWrapper.find('button#abort')).toBeDisabled();
    });
  });
});
