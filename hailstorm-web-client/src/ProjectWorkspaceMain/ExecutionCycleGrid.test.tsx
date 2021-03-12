import React, { useState } from 'react';
import { ExecutionCycleGrid } from './ExecutionCycleGrid';
import { shallow, mount, ReactWrapper } from 'enzyme';
import { CheckedExecutionCycle } from './ControlPanel';
import { Project, ExecutionCycleStatus, ExecutionCycle } from '../domain';
import { ExecutionCycleService } from "../services/ExecutionCycleService";
import { act } from '@testing-library/react';
import { AppStateContext } from '../appStateContext';

describe('<ExecutionCycleGrid />', () => {

  const Wrapper: React.FC<{
    viewTrash?: boolean;
    project: Project;
  }> = ({
    viewTrash,
    project
  }) => {
    const [executionCycles, setExecutionCycles] = useState<CheckedExecutionCycle[]>([]);

    return (
      <ExecutionCycleGrid
        {...{executionCycles, setExecutionCycles, project}}
        reloadGrid={false}
        setReloadGrid={jest.fn()}
        viewTrash={viewTrash || false}
        gridButtonStates={{stop: true, abort: true, start: false, report: true, export: true, trash: false}}
        setGridButtonStates={jest.fn()}
      />
    );
  };

  it('should not crash on render', () => {
    shallow(
      <ExecutionCycleGrid
        executionCycles={[]}
        setExecutionCycles={jest.fn()}
        reloadGrid={false}
        setReloadGrid={jest.fn()}
        viewTrash={false}
        setGridButtonStates={jest.fn()}
        gridButtonStates={{stop: true, abort: true, start: false, report: true, export: true, trash: false}}
        project={{id: 1, code: 'a', title: 'A', running: false, autoStop: false}}
      />
    )
  });

  it('should show execution cycles', (done) => {
    const activeProject: Project = {id: 1, code: 'a', title: 'A', running: false, autoStop: false};
    const apiSpy = jest.spyOn(ExecutionCycleService.prototype, 'list').mockResolvedValue([
      {
        id: 1, projectId: 11, startedAt: new Date(), stoppedAt: new Date(), responseTime: 100, threadsCount: 10, throughput: 1.48,
        status: ExecutionCycleStatus.STOPPED
      },
      {
        id: 2, projectId: 11, startedAt: new Date(), stoppedAt: new Date(), responseTime: 120, threadsCount: 20, throughput: 1.58,
        status: ExecutionCycleStatus.STOPPED
      },
    ]);

    const component: ReactWrapper = mount(
      <Wrapper project={activeProject} />
    );

    setTimeout(() => {
      expect(apiSpy).toBeCalled();
      setTimeout(() => {
        done();
        component.update();
        expect(component).toContainMatchingElements(3, 'tr');
        expect(component.find('tr').at(1)).toContainMatchingElement('input[type="checkbox"]');
        expect(component.find('tr').at(1)).toContainMatchingElement('a.is-danger');
      }, 0);
    }, 0);
  });

  it('should not have the current cycle as checkable or deletable', (done) => {
    const activeProject: Project = {id: 1, code: 'a', title: 'A', running: true, autoStop: false};
    const apiSpy = jest.spyOn(ExecutionCycleService.prototype, 'list').mockResolvedValue([
      {
        id: 1, projectId: 1, startedAt: new Date(), threadsCount: 10
      }
    ]);

    const component: ReactWrapper = mount(
      <Wrapper project={activeProject} />
    );

    setTimeout(() => {
      done();
      expect(apiSpy).toBeCalled();
      expect(component).toContainMatchingElements(1, 'tbody tr');
      expect(component.find('tbody tr')).not.toContainMatchingElement('input[type="checkbox"]');
      expect(component.find('tbody tr')).not.toContainMatchingElement('a.is-danger');
      expect(component.find('thead > tr input[type="checkbox"]')).not.toBeChecked();
    }, 0);
 });

  it('should select all if master checkbox is checked', (done) => {
    const activeProject: Project = {id: 1, code: 'a', title: 'A', running: false, autoStop: false};
    const apiSpy = jest.spyOn(ExecutionCycleService.prototype, 'list').mockResolvedValue([
      {
        id: 1, projectId: 11, startedAt: new Date(), stoppedAt: new Date(), responseTime: 100, threadsCount: 10, throughput: 1.48,
        status: ExecutionCycleStatus.STOPPED
      },
      {
        id: 2, projectId: 11, startedAt: new Date(), stoppedAt: new Date(), responseTime: 120, threadsCount: 20, throughput: 1.58,
        status: ExecutionCycleStatus.STOPPED
      },
    ]);

    const component: ReactWrapper = mount(
      <Wrapper project={activeProject} />
    );

    setTimeout(() => {
      done();
      expect(apiSpy).toBeCalled();
      expect(component.find('tbody > tr').at(0).find('input[type="checkbox"]')).not.toBeChecked();
      expect(component.find('tbody > tr').at(1).find('input[type="checkbox"]')).not.toBeChecked();
      act(() => {
        component.find('thead > tr').find('input[type="checkbox"]').simulate('change');
      });

      component.update();
      expect(component!.find('tbody > tr').at(0).find('input[type="checkbox"]')).toBeChecked();
      expect(component!.find('tbody > tr').at(1).find('input[type="checkbox"]')).toBeChecked();
    }, 0);
  });

  it('should check master checkbox if all options are checked', (done) => {
    const activeProject: Project = {id: 1, code: 'a', title: 'A', running: false, autoStop: false};
    const apiSpy = jest.spyOn(ExecutionCycleService.prototype, 'list').mockResolvedValue([
      {
        id: 1, projectId: 11, startedAt: new Date(), stoppedAt: new Date(), responseTime: 100, threadsCount: 10, throughput: 1.48,
        status: ExecutionCycleStatus.STOPPED
      },
      {
        id: 2, projectId: 11, startedAt: new Date(), stoppedAt: new Date(), responseTime: 120, threadsCount: 20, throughput: 1.58,
        status: ExecutionCycleStatus.STOPPED
      },
    ]);

    let component: ReactWrapper;
    act(() => {
      component = mount(
        <Wrapper project={activeProject} />
      );
    });

    setTimeout(() => {
      done();
      expect(apiSpy).toBeCalled();

      component.update();
      expect(component.find('thead > tr').find('input[type="checkbox"]')).toExist();
      expect(component.find('thead > tr').find('input[type="checkbox"]')).not.toBeChecked();

      component.find('tbody > tr').at(0).find('input[type="checkbox"]').simulate('change');
      component.find('tbody > tr').at(1).find('input[type="checkbox"]').simulate('change');
      expect(component.find('thead > tr').find('input[type="checkbox"]')).toBeChecked();

      component.find('tbody > tr').at(1).find('input[type="checkbox"]').simulate('change');
      expect(component.find('thead > tr').find('input[type="checkbox"]')).not.toBeChecked();
    }, 0);
  });

  it('should trash an execution cycle', (done) => {
    const activeProject: Project = {id: 1, code: 'a', title: 'A', running: false, autoStop: false};
    const execCycle: ExecutionCycle = {
      id: 1, projectId: 11, startedAt: new Date(), stoppedAt: new Date(), responseTime: 100, threadsCount: 10, throughput: 1.48,
      status: ExecutionCycleStatus.STOPPED
    };
    jest.spyOn(ExecutionCycleService.prototype, 'list').mockResolvedValue([execCycle]);

    const component: ReactWrapper = mount(
      <Wrapper project={activeProject} />
    );

    const apiSpy = jest.spyOn(ExecutionCycleService.prototype, 'update').mockResolvedValue(execCycle);
    setTimeout(() => {
      done();
      component.update();
      act(() => {
        component.find('tbody > tr').find('a.is-danger').simulate('click');
      });

      expect(apiSpy).toBeCalled();
      component.update();
      expect(component.find('tbody > tr > td').text()).toMatch(new RegExp('No tests'));
    }, 0);
  });

  it('should show trashed items when trash view is open', (done) => {
    const activeProject: Project = {id: 1, code: 'a', title: 'A', running: false, autoStop: false};
    const execCycle: ExecutionCycle = {
      id: 1, projectId: 11, startedAt: new Date(), stoppedAt: new Date(), responseTime: 100, threadsCount: 10, throughput: 1.48,
      status: ExecutionCycleStatus.EXCLUDED
    };
    jest.spyOn(ExecutionCycleService.prototype, 'list').mockResolvedValue([execCycle]);

    let component: ReactWrapper | null = null;
    act(() => {
      component = mount(
        <Wrapper project={activeProject} viewTrash={true} />
      );
    });

    setTimeout(() => {
      done();
      component!.update();
      expect(component!.find('tbody > tr a.is-danger')).toContainExactlyOneMatchingElement('i.fa-undo');
    }, 0);
  });

  it('should restore an execution cycle that was previously trashed', (done) => {
    const activeProject: Project = {id: 1, code: 'a', title: 'A', running: false, autoStop: false};
    const execCycle: ExecutionCycle = {
      id: 1, projectId: 11, startedAt: new Date(), stoppedAt: new Date(), responseTime: 100, threadsCount: 10, throughput: 1.48,
      status: ExecutionCycleStatus.EXCLUDED
    };
    jest.spyOn(ExecutionCycleService.prototype, 'list').mockResolvedValue([execCycle]);

    let component: ReactWrapper | null = null;
    act(() => {
      component = mount(
        <Wrapper project={activeProject} viewTrash={true} />
      );
    });

    setTimeout(() => {
      done();
      component!.update();
      act(() => {
        component!.find('tbody > tr a.is-danger > i.fa-undo').simulate('click');
      });
      component!.update();
      expect(component!.find('tbody > tr > td').text()).toMatch(new RegExp('No items'));
    }, 0);
  });

  it('should not check master checkbox when there are no execution cycles to show', (done) => {
    const activeProject: Project = {id: 1, code: 'a', title: 'A', running: false, autoStop: false};
    jest.spyOn(ExecutionCycleService.prototype, 'list').mockResolvedValue([]);

    let component: ReactWrapper | null = null;
    act(() => {
      component = mount(
        <Wrapper project={activeProject} />
      );
    });

    component!.update();
    setTimeout(() => {
      done();
      expect(component!.find('thead > tr input[type="checkbox"]')).not.toBeChecked();
    }, 0);

  });
});
