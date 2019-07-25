import React from 'react';
import { ExecutionCycleGrid } from './ExecutionCycleGrid';
import { shallow } from 'enzyme';

describe('<ExecutionCycleGrid />', () => {
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
      />
    )
  });
});
