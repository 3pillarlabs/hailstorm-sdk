import React, { useState, useContext, useEffect } from 'react';
import { ToolBar } from './ToolBar';
import { ExecutionCycleGrid } from './ExecutionCycleGrid';
import { ExecutionCycle } from '../domain';
import { AppStateContext } from '../appStateContext';

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
  const {appState} = useContext(AppStateContext);
  const project = appState.activeProject!;

  const [gridButtonStates, setGridButtonStates] = useState<ButtonStateLookup>({
    report: true,
    export: true,
    trash: false,
    stop: true,
    abort: true,
    start: false,
  });

  const [executionCycles, setExecutionCycles] = useState<CheckedExecutionCycle[]>([]);
  const [reloadGrid, setReloadGrid] = useState(false);
  const [viewTrash, setViewTrash] = useState(false);

  useEffect(() => setGridButtonStates({
    ...gridButtonStates,
    stop: !project.running || project.autoStop || project.interimState !== undefined,
    abort: !project.running || project.interimState !== undefined,
    start: project.running || project.interimState !== undefined,
  }), [project]);

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
