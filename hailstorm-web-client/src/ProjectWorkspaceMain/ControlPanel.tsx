import React, { useState, useContext } from 'react';
import { ToolBar } from './ToolBar';
import { ExecutionCycleGrid } from './ExecutionCycleGrid';
import { ActiveProjectContext } from '../ProjectWorkspace';
import { ExecutionCycle } from '../domain';

export interface CheckedExecutionCycle extends ExecutionCycle {
  checked: boolean | null;
}

export interface ButtonStateLookup {
  report: boolean;
  export: boolean;
  trash: boolean;
  stop: boolean;
  abort: boolean;
  start: boolean;
}

export interface ControlPanelProps {
  reloadReports: () => void;
}

export const ControlPanel: React.FC<ControlPanelProps> = (props) => {
  const {reloadReports} = props;

  const {project} = useContext(ActiveProjectContext);

  const [gridButtonStates, setGridButtonStates] = useState<ButtonStateLookup>({
    report: true,
    export: true,
    trash: false,
    stop: !project.running || project.autoStop,
    abort: !project.running,
    start: project.running,
  });
  const [executionCycles, setExecutionCycles] = useState<CheckedExecutionCycle[]>([]);
  const [reloadGrid, setReloadGrid] = useState(false);
  const [viewTrash, setViewTrash] = useState(false);

  return (
    <>
    <div className="panel">
      <div className="panel-heading">
        <i className="fas fa-flask"></i> Tests
      </div>
      <ToolBar {...{
        executionCycles,
        setExecutionCycles,
        gridButtonStates,
        setGridButtonStates,
        viewTrash,
        setReloadGrid,
        reloadReports,
        setViewTrash}}
      >
        <div className="panel-block">
          <ExecutionCycleGrid {...{
            gridButtonStates,
            setGridButtonStates,
            viewTrash,
            reloadGrid,
            setReloadGrid,
            executionCycles,
            setExecutionCycles}}
          />
        </div>
      </ToolBar>
    </div>
    </>
  );
}
